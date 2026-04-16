import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/feature_config.dart';
import '../models/device_data.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

/// DeviceNotification – một mục notification nhận được từ /noti
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

/// DeviceProvider – port 1:1 từ web/js/deviceManager.js
///
/// Quản lý registry các thiết bị tracking, telemetry state và lịch sử route.
///
/// CÁCH SỬ DỤNG:
///   1. Gọi addDevice(id) để thêm thiết bị.
///   2. Gọi bindToMqtt(mqttService) để nhận data realtime.
///   3. Lắng nghe thay đổi qua ChangeNotifier.
///
/// Luồng dữ liệu:
///   MqttService.dataMessages → _onData() → DeviceState.routePoints
///   MqttService.notifications → _onNotification() → DeviceState.lockState
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

  // ================================================================
  //  Public getters
  // ================================================================

  List<DeviceState> get devices => _devices.values.toList();
  bool get hasDevices => _devices.isNotEmpty;
  bool get mqttConnected => _mqttConnected;

  /// Thiết bị đang được chọn (active)
  DeviceState? get activeDevice =>
      _activeId != null ? _devices[_activeId] : null;

  String? get activeId => _activeId;

  /// Lịch sử notification nhận được từ /noti  (mới nhất trước)
  List<DeviceNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  // ================================================================
  //  Lifecycle
  // ================================================================

  DeviceProvider() {
    // Thêm thiết bị mặc định từ FeatureConfig
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

  // ================================================================
  //  MQTT binding
  // ================================================================

  /// Kết nối DeviceProvider với MqttService.
  /// Gọi sau khi mqtt.connect() thành công.
  void bindToMqtt(MqttService service) {
    _mqttService = service;
    _dataSub?.cancel();
    _notiSub?.cancel();
    _connSub?.cancel();

    // Stream connectionState không replay trạng thái cũ, nên đồng bộ ngay.
    _mqttConnected = service.isConnected;

    // Subscribe tất cả thiết bị hiện có
    for (final id in _devices.keys) {
      service.subscribeDevice(id);
    }

    _connSub = service.connectionState.listen((connected) {
      _mqttConnected = connected;
      notifyListeners();
    });

    // Đảm bảo UI cập nhật ngay khi vừa bind xong.
    notifyListeners();

    _dataSub = service.dataMessages.listen((msg) {
      _onData(msg.deviceId, msg.data);
    });

    _notiSub = service.notifications.listen((msg) {
      _onNotification(msg.deviceId, msg.message);
    });
  }

  // ================================================================
  //  Device registry CRUD
  // ================================================================

  /// Thêm thiết bị mới. Trả về false nếu đã tồn tại.
  bool addDevice(String id) {
    if (_devices.containsKey(id)) return false;
    _addDeviceInternal(id);
    _mqttService?.subscribeDevice(id);
    notifyListeners();
    return true;
  }

  /// Xóa thiết bị khỏi registry và hủy subscribe.
  bool removeDevice(String id) {
    if (!_devices.containsKey(id)) return false;
    _devices.remove(id);
    _mqttService?.unsubscribeDevice(id);

    // Nếu xóa active device → chọn device đầu tiên còn lại
    if (_activeId == id) {
      _activeId = _devices.isEmpty ? null : _devices.keys.first;
    }
    notifyListeners();
    return true;
  }

  /// Đặt thiết bị active (hiển thị trên bản đồ/panel).
  void setActive(String id) {
    if (!_devices.containsKey(id)) return;
    _activeId = id;
    notifyListeners();
  }

  /// Xóa lịch sử route.
  /// [id] = null → xóa tất cả thiết bị.
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

  /// Publish lệnh chuỗi đến thiết bị qua /cmd.
  bool publishCommand(String deviceId, String command) {
    final mqtt = _mqttService;
    if (mqtt == null) {
      debugPrint('[DeviceProvider] Cannot publish: MQTT not bound');
      return false;
    }
    return mqtt.publish(deviceId, command);
  }

  // ================================================================
  //  Private – data handling
  // ================================================================

  void _addDeviceInternal(String id, {int? colorIndex}) {
    final palette = FeatureConfig.deviceColorPalette;
    final ci = colorIndex ?? _devices.length;
    _devices[id] = DeviceState(
      id: id,
      color: palette[ci % palette.length],
    );
    // Tự chọn active nếu là thiết bị đầu tiên
    _activeId ??= id;
  }

  /// Xử lý data message từ <deviceId>/data
  void _onData(String deviceId, DeviceData data) {
    // Auto-register thiết bị lạ
    if (!_devices.containsKey(deviceId)) {
      if (!FeatureConfig.enableAutoRegisterDevice) return;
      debugPrint('[DeviceProvider] Auto-registering: $deviceId');
      _addDeviceInternal(deviceId);
    }

    final current = _devices[deviceId]!;
    final now = DateTime.now();

    List<RoutePoint> nextPoints = List.of(current.routePoints);

    // Thêm RoutePoint chỉ khi có GPS fix hợp lệ
    if (data.hasGps && _isValidCoord(data.lat!, data.lng!)) {
      final last = nextPoints.isNotEmpty ? nextPoints.last : null;
      final isDuplicate = last != null &&
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

  /// Xử lý notification từ <deviceId>/noti
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
          // Device vừa online lại → reset lock state
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

    // Lưu vào notification history
    _notifications.add(DeviceNotification(
      deviceId: deviceId,
      message: message,
      receivedAt: now,
    ));
    if (_notifications.length > _maxNotifications) {
      _notifications.removeAt(0);
    }

    notifyListeners();
  }

  // ================================================================
  //  Private – offline detection
  // ================================================================

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

      // Ưu tiên KEEPALIVE timeout; fallback sang data timeout
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

  // ================================================================
  //  Helpers
  // ================================================================

  static bool _isValidCoord(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}
