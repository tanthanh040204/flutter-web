// @file       vehicle.dart
// @brief      Data model for Vehicle.

/* Imports ------------------------------------------------------------ */
import 'package:latlong2/latlong.dart';

/* Public classes ----------------------------------------------------- */
class Vehicle {
  final String id;
  final String name;

  final int batteryPercent;
  final bool isLocked;
  final bool isRunning;

  final double totalKm;
  final double temp;
  final double hum;
  final double dust;
  /// Live speed from last MQTT /data (km/h); not persisted as critical odometer data.
  final double velocityKmh;

  final LatLng lastLocation;
  final DateTime updatedAt;

  const Vehicle({
    required this.id,
    required this.name,
    required this.batteryPercent,
    required this.isLocked,
    required this.isRunning,
    required this.totalKm,
    this.temp = 0,
    this.hum = 0,
    this.dust = 0,
    this.velocityKmh = 0,
    required this.lastLocation,
    required this.updatedAt,
  });

  Vehicle copyWith({
    String? name,
    int? batteryPercent,
    bool? isLocked,
    bool? isRunning,
    double? totalKm,
    double? temp,
    double? hum,
    double? dust,
    double? velocityKmh,
    LatLng? lastLocation,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id,
      name: name ?? this.name,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isLocked: isLocked ?? this.isLocked,
      isRunning: isRunning ?? this.isRunning,
      totalKm: totalKm ?? this.totalKm,
      temp: temp ?? this.temp,
      hum: hum ?? this.hum,
      dust: dust ?? this.dust,
      velocityKmh: velocityKmh ?? this.velocityKmh,
      lastLocation: lastLocation ?? this.lastLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/* End of file -------------------------------------------------------- */