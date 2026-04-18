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
//   MqttService.notifications → _onNotification() → lockState (STATE_* / OK)
// Online/offline:
//   Only KEEPALIVE on /noti sets online + lastKeepalive; if last keepalive > 60 s → offline
// Lock / unlock / resume:
//   UI: locked → UNLOCK, active → LOCK, pause → UNLOCK (resume); wait for OK on /noti (30 s)
// Device-initiated via /noti: STATE_ACTIVE, STATE_LOCK, STATE_PAUSE (do not affect online)
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

    // locked → UNLOCK→active; pause → UNLOCK→resume (active); active → LOCK→locked
    late final DeviceLockState targetState;
    late final String command;
    switch (current.lockState) {
      case DeviceLockState.locked:
        targetState = DeviceLockState.active;
        command = 'UNLOCK';
        break;
      case DeviceLockState.pause:
        targetState = DeviceLockState.active;
        command = 'UNLOCK';
        break;
      case DeviceLockState.active:
        targetState = DeviceLockState.locked;
        command = 'LOCK';
        break;
    }

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

    // Data messages do not affect online/offline — only KEEPALIVE does
    _devices[deviceId] = current.copyWith(
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

    final token = message.trim().toUpperCase();

    DeviceState next;
    switch (token) {
      case 'KEEPALIVE':
        // Only KEEPALIVE drives online; lock state unchanged
        next = current.copyWith(
          online: true,
          lastSeen: now,
          lastKeepalive: now,
        );
        break;

      case 'OK':
        // Ack for pending LOCK / UNLOCK (resume uses same UNLOCK path)
        final pending = _pendingLocks.remove(deviceId);
        if (pending != null) {
          pending.timer.cancel();
          if (pending.targetState == DeviceLockState.locked) {
            next = current.copyWith(
              lastSeen: now,
              lockState: DeviceLockState.locked,
              routePoints: [],
            );
          } else {
            next = current.copyWith(
              lastSeen: now,
              lockState: DeviceLockState.active,
              routePoints: [],
            );
          }
          if (!pending.completer.isCompleted) pending.completer.complete(true);
        } else {
          next = current.copyWith(lastSeen: now);
        }
        break;

      case 'STATE_ACTIVE':
        next = current.copyWith(
          lockState: DeviceLockState.active,
          lastSeen: now,
        );
        break;

      case 'STATE_LOCK':
        next = current.copyWith(
          lockState: DeviceLockState.locked,
          lastSeen: now,
          routePoints: [],
        );
        break;

      case 'STATE_PAUSE':
        next = current.copyWith(
          lockState: DeviceLockState.pause,
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

    final timeoutMs = FeatureConfig.keepaliveTimeoutMs;

    for (final id in _devices.keys) {
      final s = _devices[id]!;
      final lastKa = s.lastKeepalive;

      // Online is only valid with a keepalive timestamp; repair stale flags
      if (lastKa == null) {
        if (s.online) {
          _devices[id] = s.copyWith(online: false);
          changed = true;
        }
        continue;
      }

      if (!s.online) continue;

      if (now.difference(lastKa).inMilliseconds > timeoutMs) {
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
