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
  // Non-null for routes built from offline device uploads; null for live routes.
  final String? tripId;

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
    this.tripId,
  });

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmt(DateTime dt) {
    return '${_two(dt.hour)}:${_two(dt.minute)}-${_two(dt.day)}/${_two(dt.month)}';
  }

  bool get isOfflineTrip => tripId != null;

  String get buttonLabel {
    final String prefix = tripId != null ? '[Trip #$tripId] ' : '';
    final end = endAt;
    if (end == null) {
      return '$prefix${_fmt(startAt)} → receiving data';
    }
    return '$prefix${_fmt(startAt)} → ${_fmt(end)}';
  }

  // ---- JSON (used for local session persistence) ----
  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'dayKey': dayKey,
    'startAt': startAt.millisecondsSinceEpoch,
    'endAt': endAt?.millisecondsSinceEpoch,
    'isClosed': isClosed,
    'startTotalKm': startTotalKm,
    'endTotalKm': endTotalKm,
    'distanceKm': distanceKm,
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'tripId': tripId,
  };

  static HistoryRouteRecord fromJson(Map<String, dynamic> m) {
    return HistoryRouteRecord(
      id: m['id'].toString(),
      vehicleId: (m['vehicleId'] ?? '').toString(),
      dayKey: (m['dayKey'] ?? '').toString(),
      startAt: DateTime.fromMillisecondsSinceEpoch((m['startAt'] as num).toInt()),
      endAt: m['endAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((m['endAt'] as num).toInt()),
      isClosed: (m['isClosed'] ?? false) as bool,
      startTotalKm: ((m['startTotalKm'] ?? 0) as num).toDouble(),
      endTotalKm: ((m['endTotalKm'] ?? 0) as num).toDouble(),
      distanceKm: ((m['distanceKm'] ?? 0) as num).toDouble(),
      points: ((m['points'] as List?) ?? const []).map((e) {
        final p = e as List;
        return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }).toList(),
      tripId: m['tripId']?.toString(),
    );
  }
}

/* End of file -------------------------------------------------------- */
