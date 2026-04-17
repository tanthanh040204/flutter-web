// @file       trip.dart
// @brief      Data model for Trip.

/* Imports ------------------------------------------------------------ */
import 'dart:math';
import 'package:latlong2/latlong.dart';

/* Public classes ----------------------------------------------------- */
class TripPoint {
  final DateTime time;
  final LatLng latLng;
  final double speedKmh;

  const TripPoint({
    required this.time,
    required this.latLng,
    required this.speedKmh,
  });
}

class Trip {
  final String id;
  final String vehicleId;

  final DateTime startTime;
  final DateTime endTime;

  final List<TripPoint> points;

  const Trip({
    required this.id,
    required this.vehicleId,
    required this.startTime,
    required this.endTime,
    required this.points,
  });

  double get distanceKm {
    if (points.length < 2) return 0;
    double km = 0;
    for (int i = 1; i < points.length; i++) {
      km += _haversineKm(points[i - 1].latLng, points[i].latLng);
    }
    return km;
  }

  double get maxSpeedKmh {
    if (points.isEmpty) return 0;
    double m = 0;
    for (final p in points) {
      if (p.speedKmh > m) m = p.speedKmh;
    }
    return m;
  }

  double get avgSpeedKmh {
    if (points.isEmpty) return 0;
    final sum = points.fold<double>(0, (a, b) => a + b.speedKmh);
    return sum / points.length;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const double r = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return r * c;
  }

  static double _degToRad(double d) => d * (pi / 180.0);
}

/* End of file -------------------------------------------------------- */