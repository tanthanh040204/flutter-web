// @file       parking_zone.dart
// @brief      Data model for a parking zone shared via Firestore.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class ParkingZone {
  const ParkingZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.address = '',
    this.isActive = true,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String address;
  final bool isActive;
  final DateTime? updatedAt;

  factory ParkingZone.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['updatedAt'];
    final updatedAt = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
            ? raw
            : null;

    return ParkingZone(
      id: id,
      name: (map['name'] ?? id).toString(),
      lat: _asDouble(map['lat']) ?? 0.0,
      lng: _asDouble(map['lng']) ?? 0.0,
      radiusMeters: _asDouble(map['radiusMeters']) ?? 50.0,
      address: (map['address'] ?? '').toString(),
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radiusMeters': radiusMeters,
        'address': address,
        'isActive': isActive,
      };

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/* End of file -------------------------------------------------------- */
