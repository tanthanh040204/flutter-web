// @file       stats_tab.dart
// @brief      Tab UI for Stats.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../config/feature_config.dart';
import '../../models/daily_stat.dart';
import '../../models/history_route.dart';
import '../../models/vehicle.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/rental_provider.dart';
import '../../services/firebase_repo.dart';
import '../../widgets/simple_bar_chart.dart';
import '../../widgets/vehicle_picker.dart';
import '../maintenance_screen.dart';

/* Public classes ----------------------------------------------------- */
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

/* Private classes ---------------------------------------------------- */
class _StatsTabState extends State<StatsTab> {
  int days = 7;

  // Cache the Firestore route stream per vehicle so it is not re-created on
  // every FleetProvider telemetry tick (same approach as the History tab).
  String? _streamVehicleId;
  Stream<List<HistoryRouteRecord>>? _routesStream;

  Stream<List<HistoryRouteRecord>> _routesStreamFor(String vehicleId) {
    if (_routesStream == null || _streamVehicleId != vehicleId) {
      _streamVehicleId = vehicleId;
      _routesStream = FirebaseRepo.instance.watchHistoryRoutes(
        vehicleId,
        keepDays: 30,
      );
    }
    return _routesStream!;
  }

  Color _barColor(double km) {
    if (km < 70) return Colors.green;
    if (km <= 95) return Colors.orange;
    return Colors.red;
  }

  // Sum each route's distanceKm into its start day, then emit one DailyStat
  // per day across the [days] window (newest day last). This derives the chart
  // straight from saved history routes, so it works without the bridge.
  List<DailyStat> _dailyFromRoutes(List<HistoryRouteRecord> routes, int days) {
    final now = DateTime.now();
    final startDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    String keyOf(DateTime d) => '${d.year}-${d.month}-${d.day}';

    final sums = <String, double>{};
    for (final r in routes) {
      final d = r.startAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(startDay)) continue;
      final key = keyOf(day);
      sums[key] = (sums[key] ?? 0) + r.distanceKm;
    }

    final out = <DailyStat>[];
    for (int i = 0; i < days; i++) {
      final day = startDay.add(Duration(days: i));
      out.add(
        DailyStat(
          day: day,
          distanceKm: sums[keyOf(day)] ?? 0,
          avgSpeedKmh: 0,
          maxSpeedKmh: 0,
        ),
      );
    }
    return out;
  }

  // Merge session (local) + Firestore routes, deduped by id (Firestore wins),
  // exactly like the History tab so a rental isn't double-counted.
  List<HistoryRouteRecord> _mergeRoutes(
    List<HistoryRouteRecord> sessionRoutes,
    List<HistoryRouteRecord> firestoreRoutes,
  ) {
    final byId = <String, HistoryRouteRecord>{};
    for (final r in sessionRoutes) {
      byId[r.id] = r;
    }
    for (final r in firestoreRoutes) {
      byId[r.id] = r;
    }
    return byId.values.toList();
  }

  Future<void> _confirmDeleteVehicle(
    BuildContext context,
    FleetProvider fleet,
    Vehicle v,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Xóa xe', 'Delete Vehicle')),
        content: Text(
          context.tr(
            'Xóa "${v.name}" (${v.id})? Hành động này không thể hoàn tác.',
            'Delete "${v.name}" (${v.id})? This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await fleet.deleteVehicle(v.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Đã xóa ${v.id}.', '${v.id} deleted.')),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Xóa thất bại: $e', 'Delete failed: $e')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    // Watch so the chart updates when a rental ends (new session route).
    final rental = context.watch<RentalProvider>();
    final v = fleet.selectedOrNull;

    if (v == null) {
      return Scaffold(
        body: Center(
          child: Text(
            context.tr(
              'Chưa chọn xe trong Firebase.',
              'No vehicle selected in Firebase.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc(AppStrings.titleStats)),
        actions: [
          const VehiclePicker(),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: days,
              items: [
                DropdownMenuItem(
                  value: 7,
                  child: Text(context.tr('7 ngày', '7 days')),
                ),
                DropdownMenuItem(
                  value: 30,
                  child: Text(context.tr('30 ngày', '30 days')),
                ),
              ],
              onChanged: (v) => setState(() => days = v ?? 7),
            ),
          ),
          // Delete the currently selected vehicle
          IconButton(
            tooltip: context.tr('Xóa xe đang chọn', 'Delete selected vehicle'),
            icon: const Icon(Icons.delete_outline),
            color: Colors.red.shade400,
            onPressed: () => _confirmDeleteVehicle(context, fleet, v),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<HistoryRouteRecord>>(
        stream: FeatureConfig.showTripFirestore ? _routesStreamFor(v.id) : null,
        builder: (context, snap) {
          final sessionRoutes = FeatureConfig.showTripLocal
              ? rental.sessionRoutesForVehicle(v.id)
              : const <HistoryRouteRecord>[];
          final firestoreRoutes = FeatureConfig.showTripFirestore
              ? (snap.data ?? const <HistoryRouteRecord>[])
              : const <HistoryRouteRecord>[];

          final routes = _mergeRoutes(sessionRoutes, firestoreRoutes);
          final stats = _dailyFromRoutes(routes, days);
          final runningDays = stats.where((s) => s.distanceKm > 0).length;

          final values = stats.map((s) => s.distanceKm).toList();
          final labels = stats
              .map((s) => '${s.day.day}/${s.day.month}')
              .toList();
          final barColors = stats.map((s) => _barColor(s.distanceKm)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                v.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.build),
                title: Text(context.tr('Bảo trì', 'Maintenance')),
                subtitle: Text(
                  context.tr(
                    'Pin ${v.batteryPercent}%',
                    'Battery ${v.batteryPercent}%',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
                ),
              ),
              const Divider(),
              _MetricRow(
                leftTitle: context.tr('Tổng quãng đường', 'Total Distance'),
                leftValue: '${v.totalKm.toStringAsFixed(1)} km',
                rightTitle: context.tr('Số ngày có chạy', 'Days with Activity'),
                rightValue: context.tr(
                  '$runningDays ngày',
                  '$runningDays days',
                ),
              ),
              const SizedBox(height: 10),
              _MetricRow(
                leftTitle: context.tr('Pin hiện tại', 'Current Battery'),
                leftValue: '${v.batteryPercent} %',
                rightTitle: context.tr('Vị trí cuối', 'Last Location'),
                rightValue:
                    '${v.lastLocation.latitude.toStringAsFixed(4)}, ${v.lastLocation.longitude.toStringAsFixed(4)}',
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Biểu đồ quãng đường', 'Distance Chart'),
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              SimpleBarChart(
                values: values,
                labels: labels,
                barColors: barColors,
                height: 210,
                maxValue: 150,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Chi tiết theo ngày', 'Daily Details'),
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (runningDays == 0)
                ListTile(
                  dense: true,
                  title: Text(
                    context.tr(
                      'Chưa có lịch sử quãng đường theo ngày',
                      'No daily distance history available',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      'Quãng đường được tổng hợp từ lịch sử lộ trình của xe.',
                      'Distance is aggregated from the vehicle\'s saved route history.',
                    ),
                  ),
                )
              else
                ...stats.reversed.map((s) {
                  final dayText = '${s.day.day}/${s.day.month}/${s.day.year}';
                  return ListTile(
                    dense: true,
                    title: Text(dayText),
                    subtitle: Text(
                      context.tr(
                        'Quãng đường trong ngày: ${s.distanceKm.toStringAsFixed(2)} km',
                        'Distance for the day: ${s.distanceKm.toStringAsFixed(2)} km',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String leftTitle;
  final String leftValue;
  final String rightTitle;
  final String rightValue;

  const _MetricRow({
    required this.leftTitle,
    required this.leftValue,
    required this.rightTitle,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(title: leftTitle, value: leftValue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(title: rightTitle, value: rightValue),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
