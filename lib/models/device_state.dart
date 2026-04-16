import 'package:latlong2/latlong.dart';

import 'device_data.dart';

/// Một điểm trong lịch sử lộ trình của thiết bị.
/// Tương đương RoutePoint trong web/js/deviceManager.js
class RoutePoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? battery;
  final double? velocityMs;
  final double? velocityKmh;
  final double? distanceM;
  final double? directionDeg;
  final String? directionStr;
  final double? dust;
  final double? temp;
  final double? hum;

  const RoutePoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.battery,
    this.velocityMs,
    this.velocityKmh,
    this.distanceM,
    this.directionDeg,
    this.directionStr,
    this.dust,
    this.temp,
    this.hum,
  });

  LatLng get latLng => LatLng(lat, lng);

  /// Tạo RoutePoint từ DeviceData (chỉ khi hasGps == true)
  factory RoutePoint.fromDeviceData(DeviceData d) {
    return RoutePoint(
      lat: d.lat!,
      lng: d.lng!,
      timestamp: d.timestamp,
      battery: d.battery,
      velocityMs: d.velocityMs,
      velocityKmh: d.velocityKmh,
      distanceM: d.distanceM,
      directionDeg: d.directionDeg,
      directionStr: d.directionStr,
      dust: d.dust,
      temp: d.temp,
      hum: d.hum,
    );
  }
}

/// Trạng thái khóa của thiết bị (từ topic /noti)
enum DeviceLockState { active, locked }

/// Toàn bộ state của một thiết bị tracking.
/// Tương đương DeviceState object trong web/js/deviceManager.js
class DeviceState {
  final String id;
  final String color;
  final bool online;
  final DateTime? lastSeen;
  final DateTime? lastKeepalive;
  final DeviceLockState lockState;
  final DeviceData? latest;
  final List<RoutePoint> routePoints;

  const DeviceState({
    required this.id,
    required this.color,
    this.online = false,
    this.lastSeen,
    this.lastKeepalive,
    this.lockState = DeviceLockState.active,
    this.latest,
    this.routePoints = const [],
  });

  DeviceState copyWith({
    String? color,
    bool? online,
    DateTime? lastSeen,
    DateTime? lastKeepalive,
    DeviceLockState? lockState,
    DeviceData? latest,
    List<RoutePoint>? routePoints,
  }) {
    return DeviceState(
      id: id,
      color: color ?? this.color,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      lastKeepalive: lastKeepalive ?? this.lastKeepalive,
      lockState: lockState ?? this.lockState,
      latest: latest ?? this.latest,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}
