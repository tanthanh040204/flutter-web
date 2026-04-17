// @file       geo_utils.dart
// @brief      Utility helpers for Geo.

/* Imports ------------------------------------------------------------ */
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_constants.dart';
import '../models/route_point.dart';

/* Public classes ----------------------------------------------------- */
class GeoUtils {
  GeoUtils._();

  // Calculate distance between two lat/lng points using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return GeoConfig.earthRadiusKm * c;
  }

  // Calculate distance between two LatLng points
  static double calculateDistanceLatLng(LatLng point1, LatLng point2) {
    return calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Calculate total distance of a route
  static double calculateTotalDistance(List<RoutePoint> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += calculateDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  // Calculate bounds of a route
  static LatLngBounds? calculateBounds(List<RoutePoint> points) {
    if (points.isEmpty) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  // Calculate center of a route
  static LatLng? calculateCenter(List<RoutePoint> points) {
    if (points.isEmpty) return null;

    double sumLat = 0;
    double sumLng = 0;

    for (final point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  // Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Format distance
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }
}

/* End of file -------------------------------------------------------- */
