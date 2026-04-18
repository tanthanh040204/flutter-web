// @file       device_provider.dart
// @brief      State provider for Device — manages real-time MQTT device state.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/feature_config.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

/* Public classes ----------------------------------------------------- */
class DeviceNotification {
  final String deviceId;
  final String message;
  final DateTime receivedAt;

  const DeviceNotification({
    required this.deviceId,
    required this.message,
    required this.receivedAt,
  });
}

// DeviceProvider manages real-time state of all MQTT-connected devices.
// Data flow:
//   MqttService.dataMessages  → _onDataMessage() → DeviceState.routePoints
//   MqttService.notifications → _onNotification() → DeviceState.lockState
// Lock/Unlock flow:
//   UI calls sendInlock(id) → publish 'LOCK' or 'UNLOCK' → wait for 'OK' on /noti (30 s timeout)
class DeviceProvider extends ChangeNotifier {
  // ---- Device registry ----
  final Map<String, DeviceState> _devices = {};
  String? _activeId;

  // ---- MQTT ----
  MqttService? _mqttService;
  StreamSubscription<MqttDataMessage>? _dataSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  StreamSubscription<bool>? _connSub;
  bool _mqttConnected = false;

  // ---- Offline detection ----
  Timer? _offlineTimer;

  // ---- Notification history (for debug / UI) ----
  final List<DeviceNotification> _notifications = [];
  static const int _maxNotifications = 50;

  // ---- Raw debug logs (circular buffer per device) ----
  final Map<String, List<String>> _rawDataLog = {};
  final Map<String, List<String>> _rawNotiLog = {};
  static const int _maxLogLines = 50;

  // ---- Pending UNLOCK tracking (one per device) ----
  final Map<String, _PendingLock> _pendingLocks = {};

  // Public getters
  List<DeviceState> get devices => _devices.values.toList();
  bool get hasDevices => _devices.isNotEmpty;
  bool get mqttConnected => _mqttConnected;
  String? get activeId => _activeId;

  DeviceState? get activeDevice =>
      _activeId != null ? _devices[_activeId] : null;

  DeviceState? deviceById(String id) => _devices[id];

  List<DeviceNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  bool isPendingLock(String deviceId) => _pendingLocks.containsKey(deviceId);

  // Last N raw data lines for device (newest first)
  List<String> rawDataLog(String deviceId) =>
      List.unmodifiable((_rawDataLog[deviceId] ?? []).reversed.toList());

  // Last N raw noti lines for device (newest first)
  List<String> rawNotiLog(String deviceId) =>
      List.unmodifiable((_rawNotiLog[deviceId] ?? []).reversed.toList());

  DeviceProvider() {
    for (var i = 0; i < FeatureConfig.defaultDevices.length; i++) {
      _addDeviceInternal(FeatureConfig.defaultDevices[i], colorIndex: i);
    }
    if (FeatureConfig.enableOfflineDetection) {
      _startOfflineTimer();
    }
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    _dataSub?.cancel();
    _notiSub?.cancel();
    _connSub?.cancel();
    for (final p in _pendingLocks.values) {
      p.timer.cancel();
      if (!p.completer.isCompleted) p.completer.complete(false);
    }
    _pendingLocks.clear();
    super.dispose();
  }

  // Bind to MqttService — subscribes to all streams.
  void bindToMqtt(MqttService service) {
    _mqttService = service;
    _dataSub?.cancel();
    _notiSub?.cancel();
    _connSub?.cancel();

    _mqttConnected = service.isConnected;

    for (final id in _devices.keys) {
      service.subscribeDevice(id);
    }

    _connSub = service.connectionState.listen((connected) {
      _mqttConnected = connected;
      notifyListeners();
    });

    _dataSub = service.dataMessages.listen(_onDataMessage);
    _notiSub = service.notifications.listen((msg) {
      _onNotification(msg.deviceId, msg.message);
    });

    notifyListeners();
  }

  // Add device to registry and subscribe to its MQTT topics.
  bool addDevice(String id) {
    if (_devices.containsKey(id)) return false;
    _addDeviceInternal(id);
    _mqttService?.subscribeDevice(id);
    notifyListeners();
    return true;
  }

  // Remove device from registry and unsubscribe MQTT topics.
  bool removeDevice(String id) {
    if (!_devices.containsKey(id)) return false;
    _devices.remove(id);
    _rawDataLog.remove(id);
    _rawNotiLog.remove(id);
    _mqttService?.unsubscribeDevice(id);

    final pending = _pendingLocks.remove(id);
    pending?.timer.cancel();
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(false);
    }

    if (_activeId == id) {
      _activeId = _devices.isEmpty ? null : _devices.keys.first;
    }
    notifyListeners();
    return true;
  }

  void setActive(String id) {
    if (!_devices.containsKey(id)) return;
    _activeId = id;
    notifyListeners();
  }

  // Clear route for one device (or all if id is null).
  void clearRoute([String? id]) {
    if (id != null) {
      final s = _devices[id];
      if (s != null) _devices[id] = s.copyWith(routePoints: [], latest: null);
    } else {
      for (final key in _devices.keys) {
        final s = _devices[key]!;
        _devices[key] = s.copyWith(routePoints: [], latest: null);
      }
    }
    notifyListeners();
  }

  bool publishCommand(String deviceId, String command) {
    final mqtt = _mqttService;
    if (mqtt == null) {
      debugPrint('[DeviceProvider] Cannot publish: MQTT not bound');
      return false;
    }
    return mqtt.publish(deviceId, command);
  }

  // Send LOCK or UNLOCK command and wait for OK response (max 30 s).
  // Returns true if OK received, false on timeout or error.
  Future<bool> sendInlock(String deviceId) async {
    final mqtt = _mqttService;
    if (mqtt == null || !_mqttConnected) return false;

    final current = _devices[deviceId];
    if (current == null) return false;

    // Cancel any in-flight pending lock for this device
    _pendingLocks[deviceId]?.timer.cancel();
    if (_pendingLocks[deviceId]?.completer.isCompleted == false) {
      _pendingLocks[deviceId]!.completer.complete(false);
    }

    // Toggle: active/pause → locked, locked → active
    final targetState = current.lockState == DeviceLockState.locked
        ? DeviceLockState.active
        : DeviceLockState.locked;

    final completer = Completer<bool>();
    final timer = Timer(const Duration(seconds: 30), () {
      _pendingLocks.remove(deviceId);
      if (!completer.isCompleted) completer.complete(false);
      notifyListeners();
    });

    _pendingLocks[deviceId] = _PendingLock(
      targetState: targetState,
      completer: completer,
      timer: timer,
    );

    notifyListeners();

    // Button "Unlock" → send 'UNLOCK' (locked→active), Button "Lock" → send 'LOCK' (active→locked)
    final command = targetState == DeviceLockState.active ? 'UNLOCK' : 'LOCK';
    final sent = mqtt.publish(deviceId, command);
    if (!sent) {
      _pendingLocks.remove(deviceId);
      timer.cancel();
      if (!completer.isCompleted) completer.complete(false);
      notifyListeners();
    }

    return completer.future;
  }

  // Private helpers
  void _addDeviceInternal(String id, {int? colorIndex}) {
    final palette = FeatureConfig.deviceColorPalette;
    final ci = colorIndex ?? _devices.length;
    // Start as locked until the device confirms its state via noti
    _devices[id] = DeviceState(
      id: id,
      color: palette[ci % palette.length],
      lockState: DeviceLockState.locked,
    );
    _activeId ??= id;
  }

  void _onDataMessage(MqttDataMessage msg) {
    final deviceId = msg.deviceId;
    final data = msg.data;

    if (!_devices.containsKey(deviceId)) {
      if (!FeatureConfig.enableAutoRegisterDevice) return;
      debugPrint('[DeviceProvider] Auto-registering: $deviceId');
      _addDeviceInternal(deviceId);
    }

    final current = _devices[deviceId]!;
    final now = DateTime.now();

    // Append raw data to debug log
    _appendLog(_rawDataLog, deviceId, _fmtTime(now), msg.raw);

    List<RoutePoint> nextPoints = List.of(current.routePoints);

    // Accumulate route only when vehicle is active or paused (not locked)
    if (current.lockState != DeviceLockState.locked &&
        data.hasGps &&
        _isValidCoord(data.lat!, data.lng!)) {
      final last = nextPoints.isNotEmpty ? nextPoints.last : null;
      final isDuplicate =
          last != null &&
          last.timestamp == data.timestamp &&
          last.lat == data.lat &&
          last.lng == data.lng;

      if (!isDuplicate) {
        nextPoints.add(RoutePoint.fromDeviceData(data));
      }
    }

    _devices[deviceId] = current.copyWith(
      online: true,
      lastSeen: now,
      latest: data,
      routePoints: nextPoints,
    );

    notifyListeners();
  }

  void _onNotification(String deviceId, String message) {
    if (!_devices.containsKey(deviceId)) {
      if (!FeatureConfig.enableAutoRegisterDevice) return;
      _addDeviceInternal(deviceId);
    }

    final current = _devices[deviceId]!;
    final now = DateTime.now();

    // Append raw noti to debug log
    _appendLog(_rawNotiLog, deviceId, _fmtTime(now), message);

    DeviceState next;
    switch (message) {
      case 'KEEPALIVE':
        final wasOnline = current.online;
        next = current.copyWith(
          online: true,
          lastSeen: now,
          lastKeepalive: now,
          // Restore to active only if device was previously offline
          lockState: wasOnline ? null : DeviceLockState.active,
        );
        break;

      case 'OK':
        // Acknowledgment for UNLOCK command
        final pending = _pendingLocks.remove(deviceId);
        if (pending != null) {
          pending.timer.cancel();
          if (pending.targetState == DeviceLockState.locked) {
            // Locking: clear route on confirmed lock
            next = current.copyWith(
              online: true,
              lastSeen: now,
              lockState: DeviceLockState.locked,
              routePoints: [],
            );
          } else {
            // Unlocking: start fresh route
            next = current.copyWith(
              online: true,
              lastSeen: now,
              lockState: DeviceLockState.active,
              routePoints: [],
            );
          }
          if (!pending.completer.isCompleted) pending.completer.complete(true);
        } else {
          next = current.copyWith(online: true, lastSeen: now);
        }
        break;

      case 'USER LOCK':
        // Vehicle locked externally — clear route
        next = current.copyWith(
          lockState: DeviceLockState.locked,
          online: true,
          lastSeen: now,
          routePoints: [],
        );
        break;

      case 'PAUSE':
        // Renter temporarily paused the vehicle
        next = current.copyWith(
          lockState: DeviceLockState.pause,
          online: true,
          lastSeen: now,
        );
        break;

      default:
        debugPrint('[DeviceProvider] Unknown noti [$deviceId]: "$message"');
        next = current;
    }

    _devices[deviceId] = next;

    _notifications.add(
      DeviceNotification(deviceId: deviceId, message: message, receivedAt: now),
    );
    if (_notifications.length > _maxNotifications) {
      _notifications.removeAt(0);
    }

    notifyListeners();
  }

  void _startOfflineTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer.periodic(
      Duration(milliseconds: FeatureConfig.offlineCheckIntervalMs),
      (_) => _checkOffline(),
    );
  }

  void _checkOffline() {
    final now = DateTime.now();
    bool changed = false;

    for (final id in _devices.keys) {
      final s = _devices[id]!;
      if (!s.online) continue;

      // Use lastSeen (updated by both data and KEEPALIVE) so data messages
      // also reset the offline timer, not just KEEPALIVE alone.
      final lastSeen = s.lastSeen;
      if (lastSeen == null) continue;

      if (now.difference(lastSeen).inMilliseconds > FeatureConfig.keepaliveTimeoutMs) {
        _devices[id] = s.copyWith(online: false);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  void _appendLog(
    Map<String, List<String>> logMap,
    String deviceId,
    String time,
    String text,
  ) {
    final log = logMap.putIfAbsent(deviceId, () => []);
    log.add('[$time] $text');
    if (log.length > _maxLogLines) log.removeAt(0);
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static bool _isValidCoord(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/* Private classes ---------------------------------------------------- */
class _PendingLock {
  final DeviceLockState targetState;
  final Completer<bool> completer;
  final Timer timer;

  const _PendingLock({
    required this.targetState,
    required this.completer,
    required this.timer,
  });
}

/* End of file -------------------------------------------------------- */
