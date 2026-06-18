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

  static const List<ParkingZone> defaultSeed = <ParkingZone>[
    ParkingZone(
      id: 'PZ001',
      name: '9/2g 904 street, Hiep Phu',
      lat: 10.853205,
      lng: 106.782647,
      radiusMeters: 50.0,
    ),
    ParkingZone(
      id: 'PZ002',
      name: 'UTE university, district 9',
      lat: 10.849908,
      lng: 106.771621,
      radiusMeters: 80.0,
    ),
    ParkingZone(
      id: 'PZ003',
      name: 'UTE D2, Le Van Viet street',
      lat: 10.846085,
      lng: 106.797446,
      radiusMeters: 60.0,
    ),
    ParkingZone(
      id: 'PZ004',
      name: 'Khu C, UTE',
      lat: 10.853257605857388,
      lng: 106.77183955420634,
      radiusMeters: 60.0,
    ),
  ];

  static List<ParkingZone> mergeRemoteAndLocal(
    Iterable<ParkingZone> remote, {
    Iterable<ParkingZone> local = defaultSeed,
    bool includeLocal = true,
  }) {
    final byId = <String, ParkingZone>{};
    for (final zone in remote) {
      if (zone.isActive) byId[zone.id] = zone;
    }
    if (includeLocal) {
      for (final zone in local) {
        if (zone.isActive) byId[zone.id] = zone;
      }
    }
    final merged = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return merged;
  }
}

/* End of file -------------------------------------------------------- */
