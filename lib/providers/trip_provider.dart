import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/daily_stat.dart';
import '../models/trip.dart';
import '../services/firebase_repo.dart';

class TripProvider extends ChangeNotifier {
  final Map<String, List<Trip>> _tripsByVehicle = {};
  final Map<String, StreamSubscription<List<Trip>>> _tripSubs = {};

  final Map<String, List<DailyStat>> _dailyUsageByVehicle = {};
  final Map<String, StreamSubscription<List<DailyStat>>> _dailyUsageSubs = {};

  List<Trip> tripsFor(String vehicleId) =>
      List.unmodifiable(_tripsByVehicle[vehicleId] ?? const <Trip>[]);

  void bindVehicles(List<String> vehicleIds) {
    final wanted = vehicleIds.toSet();

    final removedTrips =
        _tripSubs.keys.where((id) => !wanted.contains(id)).toList();
    for (final id in removedTrips) {
      _tripSubs.remove(id)?.cancel();
      _tripsByVehicle.remove(id);
    }

    final removedDaily =
        _dailyUsageSubs.keys.where((id) => !wanted.contains(id)).toList();
    for (final id in removedDaily) {
      _dailyUsageSubs.remove(id)?.cancel();
      _dailyUsageByVehicle.remove(id);
    }

    for (final id in wanted) {
      if (!_tripSubs.containsKey(id)) {
        _tripSubs[id] = FirebaseRepo.instance.watchTrips(id).listen(
          (trips) {
            final sorted = [...trips]
              ..sort((a, b) => b.startTime.compareTo(a.startTime));
            _tripsByVehicle[id] = sorted;
            notifyListeners();
          },
          onError: (_) {
            _tripsByVehicle[id] = const <Trip>[];
            notifyListeners();
          },
        );
      }

      if (!_dailyUsageSubs.containsKey(id)) {
        _dailyUsageSubs[id] = FirebaseRepo.instance.watchDailyUsage(id).listen(
          (stats) {
            _dailyUsageByVehicle[id] = stats;
            notifyListeners();
          },
          onError: (_) {
            _dailyUsageByVehicle[id] = const <DailyStat>[];
            notifyListeners();
          },
        );
      }
    }

    notifyListeners();
  }

  List<DailyStat> persistedDailyStats(String vehicleId, {required int days}) {
    final now = DateTime.now();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final current = _dailyUsageByVehicle[vehicleId] ?? const <DailyStat>[];
    final byDay = {
      for (final s in current)
        _dayKey(DateTime(s.day.year, s.day.month, s.day.day)): s,
    };

    final List<DailyStat> out = [];
    for (int i = 0; i < days; i++) {
      final day = startDay.add(Duration(days: i));
      final key = _dayKey(day);

      out.add(
        byDay[key] ??
            DailyStat(
              day: day,
              distanceKm: 0,
              avgSpeedKmh: 0,
              maxSpeedKmh: 0,
            ),
      );
    }

    return out;
  }

  int persistedRunningDays(String vehicleId, {required int days}) {
    final now = DateTime.now();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final current = _dailyUsageByVehicle[vehicleId] ?? const <DailyStat>[];
    final keys = current
        .map((s) => _dayKey(DateTime(s.day.year, s.day.month, s.day.day)))
        .toSet();

    int count = 0;
    for (int i = 0; i < days; i++) {
      final day = startDay.add(Duration(days: i));
      if (keys.contains(_dayKey(day))) {
        count++;
      }
    }
    return count;
  }

  // ===== phần trips cũ giữ lại =====

  Future<void> generateMockDataForVehicles(List<String> vehicleIds) async {
    bindVehicles(vehicleIds);
    for (final id in vehicleIds) {
      final trips = _generate30Days(vehicleId: id);
      for (final t in trips) {
        await FirebaseRepo.instance.saveTrip(t.vehicleId, t);
      }
    }
  }

  List<DailyStat> dailyStats(String vehicleId, {required int days}) {
    final now = DateTime.now();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final trips = tripsFor(vehicleId)
        .where(
          (t) =>
              t.startTime.isAfter(startDay.subtract(const Duration(days: 1))),
        )
        .toList();

    final Map<String, List<Trip>> byDay = {};
    for (final t in trips) {
      final d = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
      final key = _dayKey(d);
      byDay.putIfAbsent(key, () => []).add(t);
    }

    final List<DailyStat> stats = [];
    for (int i = 0; i < days; i++) {
      final day = startDay.add(Duration(days: i));
      final key = _dayKey(day);
      final list = byDay[key] ?? const <Trip>[];

      double dist = 0;
      double maxSpeed = 0;
      double avgSpeedSum = 0.0;
      int avgCount = 0;

      for (final t in list) {
        dist += t.distanceKm;
        if (t.maxSpeedKmh > maxSpeed) maxSpeed = t.maxSpeedKmh;
        avgSpeedSum += t.avgSpeedKmh;
        avgCount++;
      }

      final avgSpeed = avgCount == 0 ? 0.0 : avgSpeedSum / avgCount;

      stats.add(
        DailyStat(
          day: day,
          distanceKm: dist,
          avgSpeedKmh: avgSpeed,
          maxSpeedKmh: maxSpeed,
        ),
      );
    }
    return stats;
  }

  double totalDistance(String vehicleId, {required int days}) =>
      dailyStats(vehicleId, days: days)
          .fold<double>(0, (a, b) => a + b.distanceKm);

  double avgSpeed(String vehicleId, {required int days}) {
    final stats = dailyStats(vehicleId, days: days);
    final nonZero = stats.where((s) => s.avgSpeedKmh > 0).toList();
    if (nonZero.isEmpty) return 0;
    final sum = nonZero.fold<double>(0, (a, b) => a + b.avgSpeedKmh);
    return sum / nonZero.length;
  }

  double maxSpeed(String vehicleId, {required int days}) {
    final stats = dailyStats(vehicleId, days: days);
    double m = 0;
    for (final s in stats) {
      if (s.maxSpeedKmh > m) m = s.maxSpeedKmh;
    }
    return m;
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<Trip> _generate30Days({required String vehicleId}) {
    final rnd = Random(vehicleId.hashCode);
    final now = DateTime.now();
    final List<Trip> trips = [];

    final base = vehicleId == 'V1'
        ? const LatLng(21.0287, 105.8522)
        : const LatLng(21.0310, 105.8470);

    for (int d = 0; d < 30; d++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: d));
      final tripCount = rnd.nextInt(3);

      for (int k = 0; k < tripCount; k++) {
        final start = day.add(
          Duration(hours: 7 + rnd.nextInt(12), minutes: rnd.nextInt(50)),
        );
        final durationMin = 8 + rnd.nextInt(35);
        final end = start.add(Duration(minutes: durationMin));

        final points = _generatePoints(
          base: base,
          start: start,
          minutes: durationMin,
          rnd: rnd,
        );

        trips.add(
          Trip(
            id: 'T_${vehicleId}_${day.millisecondsSinceEpoch}_$k',
            vehicleId: vehicleId,
            startTime: start,
            endTime: end,
            points: points,
          ),
        );
      }
    }
    return trips;
  }

  List<TripPoint> _generatePoints({
    required LatLng base,
    required DateTime start,
    required int minutes,
    required Random rnd,
  }) {
    final int n = max(12, minutes);
    final List<TripPoint> points = [];

    double lat = base.latitude + (rnd.nextDouble() - 0.5) * 0.01;
    double lon = base.longitude + (rnd.nextDouble() - 0.5) * 0.01;

    for (int i = 0; i < n; i++) {
      lat += (rnd.nextDouble() - 0.5) * 0.0015;
      lon += (rnd.nextDouble() - 0.5) * 0.0015;

      final speed = 8 + rnd.nextDouble() * 38;
      points.add(
        TripPoint(
          time: start.add(Duration(minutes: (i * minutes / n).round())),
          latLng: LatLng(lat, lon),
          speedKmh: speed,
        ),
      );
    }
    return points;
  }

  @override
  void dispose() {
    for (final sub in _tripSubs.values) {
      sub.cancel();
    }
    for (final sub in _dailyUsageSubs.values) {
      sub.cancel();
    }
    _tripSubs.clear();
    _dailyUsageSubs.clear();
    super.dispose();
  }
}