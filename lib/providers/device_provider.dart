// @file       device_provider.dart
// @brief      State provider for Device.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/feature_config.dart';
import '../models/device_data.dart';
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

// DeviceProvider
// Manages the state of all ddevices
// How to use:
//   1. Call addDevice(id) to add a device.
//   2. Call bindToMqtt(mqttService) to receive real-time data.
//   3. Listen for changes via ChangeNotifier.
// Data flow:
//   MqttService.dataMessages → _onData() → DeviceState.routePoints
//   MqttService.notifications → _onNotification() → DeviceState.lockState
class DeviceProvider extends ChangeNotifier {
  // ---- Registry ----
  final Map<String, DeviceState> _devices = {};
  String? _activeId;

  // ---- MQTT subscriptions ----
  MqttService? _mqttService;
  StreamSubscription<MqttDataMessage>? _dataSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  StreamSubscription<bool>? _connSub;

  // ---- Connection state ----
  bool _mqttConnected = false;

  // ---- Offline detection ----
  Timer? _offlineTimer;

  // ---- Notification history ----
  final List<DeviceNotification> _notifications = [];
  static const int _maxNotifications = 50;

  // Public getters ===============================================
  List<DeviceState> get devices => _devices.values.toList();
  bool get hasDevices => _devices.isNotEmpty;
  bool get mqttConnected => _mqttConnected;

  // Active device (for map/panel display). Null if no devices.
  DeviceState? get activeDevice =>
      _activeId != null ? _devices[_activeId] : null;

  String? get activeId => _activeId;

  // Notification history (newest first)
  List<DeviceNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  // Lifecycle
  DeviceProvider() {
    // Auto-register default devices from config (for demo/testing).
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
    super.dispose();
  }

  // Connect to mqtt service
  // After blinding, the provider will automatically update
  void bindToMqtt(MqttService service) {
    _mqttService = service;
    _dataSub?.cancel();
    _notiSub?.cancel();
    _connSub?.cancel();

    // Stream connectionState.
    _mqttConnected = service.isConnected;
    // Subscribe all existing devices to receive data/notifications.
    for (final id in _devices.keys) {
      service.subscribeDevice(id);
    }

    _connSub = service.connectionState.listen((connected) {
      _mqttConnected = connected;
      notifyListeners();
    });

    // Subscribe to data and notification streams.
    notifyListeners();

    _dataSub = service.dataMessages.listen((msg) {
      _onData(msg.deviceId, msg.data);
    });

    _notiSub = service.notifications.listen((msg) {
      _onNotification(msg.deviceId, msg.message);
    });
  }

  // Device registry management
  // Add a device to the registry and subscribe to its MQTT topic.
  bool addDevice(String id) {
    if (_devices.containsKey(id)) return false;
    _addDeviceInternal(id);
    _mqttService?.subscribeDevice(id);
    notifyListeners();
    return true;
  }

  // Remove a device from the registry and unsubscribe from its MQTT topic.
  bool removeDevice(String id) {
    if (!_devices.containsKey(id)) return false;
    _devices.remove(id);
    _mqttService?.unsubscribeDevice(id);

    // If the removed device is active, reset activeId to another device or null.
    if (_activeId == id) {
      _activeId = _devices.isEmpty ? null : _devices.keys.first;
    }
    notifyListeners();
    return true;
  }

  // Set a device as active (displayed on the map/panel).
  void setActive(String id) {
    if (!_devices.containsKey(id)) return;
    _activeId = id;
    notifyListeners();
  }

  // Clear route points for a device (or all devices if id is null).
  void clearRoute([String? id]) {
    if (id != null) {
      final s = _devices[id];
      if (s != null) {
        _devices[id] = s.copyWith(routePoints: [], latest: null);
      }
    } else {
      for (final key in _devices.keys) {
        final s = _devices[key]!;
        _devices[key] = s.copyWith(routePoints: [], latest: null);
      }
    }
    notifyListeners();
  }

  // Publish a command to a device via MQTT.
  bool publishCommand(String deviceId, String command) {
    final mqtt = _mqttService;
    if (mqtt == null) {
      debugPrint('[DeviceProvider] Cannot publish: MQTT not bound');
      return false;
    }
    return mqtt.publish(deviceId, command);
  }

  // Private methods ===============================================
  void _addDeviceInternal(String id, {int? colorIndex}) {
    final palette = FeatureConfig.deviceColorPalette;
    final ci = colorIndex ?? _devices.length;
    _devices[id] = DeviceState(id: id, color: palette[ci % palette.length]);
    // Auto activate the first added device
    _activeId ??= id;
  }

  // Handle incoming data
  void _onData(String deviceId, DeviceData data) {
    // Auto-register unknown device
    if (!_devices.containsKey(deviceId)) {
      if (!FeatureConfig.enableAutoRegisterDevice) return;
      debugPrint('[DeviceProvider] Auto-registering: $deviceId');
      _addDeviceInternal(deviceId);
    }

    final current = _devices[deviceId]!;
    final now = DateTime.now();

    List<RoutePoint> nextPoints = List.of(current.routePoints);

    // Add RoutePoint only when there is a valid GPS fix
    if (data.hasGps && _isValidCoord(data.lat!, data.lng!)) {
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

  // Handle notifications from <deviceId>/noti
  void _onNotification(String deviceId, String message) {
    // Auto-register
    if (!_devices.containsKey(deviceId)) {
      if (!FeatureConfig.enableAutoRegisterDevice) return;
      _addDeviceInternal(deviceId);
    }

    final current = _devices[deviceId]!;
    final now = DateTime.now();

    DeviceState next;
    switch (message) {
      case 'KEEPALIVE':
        final wasOnline = current.online;
        next = current.copyWith(
          online: true,
          lastSeen: now,
          lastKeepalive: now,
          // Set lockState to active if it was previously offline (null) to prevent
          lockState: wasOnline ? null : DeviceLockState.active,
        );
        break;

      case 'USER LOCK':
        next = current.copyWith(lockState: DeviceLockState.locked);
        break;

      default:
        debugPrint('[DeviceProvider] Unknown noti [$deviceId]: "$message"');
        next = current;
    }

    _devices[deviceId] = next;

    // Save notification to history (for display in UI)
    _notifications.add(
      DeviceNotification(deviceId: deviceId, message: message, receivedAt: now),
    );
    if (_notifications.length > _maxNotifications) {
      _notifications.removeAt(0);
    }

    notifyListeners();
  }

  // Offline detection
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

      final lastPing = s.lastKeepalive ?? s.lastSeen;
      if (lastPing == null) continue;

      final elapsed = now.difference(lastPing).inMilliseconds;
      final timeout = s.lastKeepalive != null
          ? FeatureConfig.keepaliveTimeoutMs
          : FeatureConfig.offlineTimeoutMs;

      if (elapsed > timeout) {
        _devices[id] = s.copyWith(online: false);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  static bool _isValidCoord(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/* End of file -------------------------------------------------------- */
