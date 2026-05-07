// @file       history_route.dart
// @brief      Data model for History Route.

/* Imports ------------------------------------------------------------ */
import 'package:latlong2/latlong.dart';

/* Public classes ----------------------------------------------------- */
class HistoryRouteRecord {
  final String id;
  final String vehicleId;
  final String dayKey;
  final DateTime startAt;
  final DateTime? endAt;
  final bool isClosed;
  final double startTotalKm;
  final double endTotalKm;
  final double distanceKm;
  final List<LatLng> points;

  const HistoryRouteRecord({
    required this.id,
    required this.vehicleId,
    required this.dayKey,
    required this.startAt,
    required this.endAt,
    required this.isClosed,
    required this.startTotalKm,
    required this.endTotalKm,
    required this.distanceKm,
    required this.points,
  });

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmt(DateTime dt) {
    return '${_two(dt.hour)}:${_two(dt.minute)}-${_two(dt.day)}/${_two(dt.month)}';
  }

  String get buttonLabel {
    final end = endAt;
    if (end == null) {
      return '${_fmt(startAt)} → receiving data';
    }
    return '${_fmt(startAt)} → ${_fmt(end)}';
  }
}

/* End of file -------------------------------------------------------- */