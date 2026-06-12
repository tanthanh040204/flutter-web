// @file       trip_provider.dart
// @brief      State provider for Trip.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/daily_stat.dart';
import '../models/trip.dart';
import '../services/firebase_repo.dart';

/* Public classes ----------------------------------------------------- */
class TripProvider extends ChangeNotifier {
  final Map<String, List<Trip>> _tripsByVehicle = {};
  final Map<String, StreamSubscription<List<Trip>>> _tripSubs = {};

  final Map<String, List<DailyStat>> _dailyUsageByVehicle = {};
  final Map<String, StreamSubscription<List<DailyStat>>> _dailyUsageSubs = {};

  List<Trip> tripsFor(String vehicleId) =>
      List.unmodifiable(_tripsByVehicle[vehicleId] ?? const <Trip>[]);

  void bindVehicles(List<String> vehicleIds) {
    final wanted = vehicleIds.toSet();

    final removedTrips = _tripSubs.keys
        .where((id) => !wanted.contains(id))
        .toList();
    for (final id in removedTrips) {
      _tripSubs.remove(id)?.cancel();
      _tripsByVehicle.remove(id);
    }

    final removedDaily = _dailyUsageSubs.keys
        .where((id) => !wanted.contains(id))
        .toList();
    for (final id in removedDaily) {
      _dailyUsageSubs.remove(id)?.cancel();
      _dailyUsageByVehicle.remove(id);
    }

    for (final id in wanted) {
      if (!_tripSubs.containsKey(id)) {
        _tripSubs[id] = FirebaseRepo.instance
            .watchTrips(id)
            .listen(
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
        _dailyUsageSubs[id] = FirebaseRepo.instance
            .watchDailyUsage(id)
            .listen(
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
            DailyStat(day: day, distanceKm: 0, avgSpeedKmh: 0, maxSpeedKmh: 0),
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
    // Count only days the vehicle actually moved (distance > 0), not just days
    // that happen to have a daily_usage doc.
    final keys = current
        .where((s) => s.distanceKm > 0)
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

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

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

/* End of file -------------------------------------------------------- */
