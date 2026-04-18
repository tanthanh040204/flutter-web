// @file       stats_tab.dart
// @brief      Tab UI for Stats.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/trip_provider.dart';
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

  Color _barColor(double km) {
    if (km < 70) return Colors.green;
    if (km <= 95) return Colors.orange;
    return Colors.red;
  }

  Future<void> _confirmDeleteVehicle(
    BuildContext context,
    FleetProvider fleet,
    Vehicle v,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Delete "${v.name}" (${v.id})? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await fleet.deleteVehicle(v.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${v.id} deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final tripProvider = context.watch<TripProvider>();
    final v = fleet.selectedOrNull;

    if (v == null) {
      return const Scaffold(
        body: Center(child: Text('No vehicle selected in Firebase.')),
      );
    }

    final stats = tripProvider.persistedDailyStats(v.id, days: days);
    final runningDays = tripProvider.persistedRunningDays(v.id, days: days);

    final values = stats.map((s) => s.distanceKm).toList();
    final labels = stats.map((s) => '${s.day.day}/${s.day.month}').toList();
    final barColors = stats.map((s) => _barColor(s.distanceKm)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          const VehiclePicker(),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: days,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
              ],
              onChanged: (v) => setState(() => days = v ?? 7),
            ),
          ),
          // Delete the currently selected vehicle
          IconButton(
            tooltip: 'Delete selected vehicle',
            icon: const Icon(Icons.delete_outline),
            color: Colors.red.shade400,
            onPressed: () => _confirmDeleteVehicle(context, fleet, v),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            v.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.build),
            title: const Text('Maintenance'),
            subtitle: Text('Battery ${v.batteryPercent}%'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
            ),
          ),
          const Divider(),
          _MetricRow(
            leftTitle: 'Total Distance',
            leftValue: '${v.totalKm.toStringAsFixed(1)} km',
            rightTitle: 'Days with Activity',
            rightValue: '$runningDays days',
          ),
          const SizedBox(height: 10),
          _MetricRow(
            leftTitle: 'Current Battery',
            leftValue: '${v.batteryPercent} %',
            rightTitle: 'Last Location',
            rightValue:
                '${v.lastLocation.latitude.toStringAsFixed(4)}, ${v.lastLocation.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 16),
          const Text(
            'Distance Chart',
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
          const Text(
            'Daily Details',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (runningDays == 0)
            const ListTile(
              dense: true,
              title: Text('No daily distance history available'),
              subtitle: Text(
                'When the app/web receives totalKm, Firebase will automatically save the data for up to 30 days.',
              ),
            )
          else
            ...stats.reversed.map((s) {
              final dayText = '${s.day.day}/${s.day.month}/${s.day.year}';
              return ListTile(
                dense: true,
                title: Text(dayText),
                subtitle: Text(
                  'Distance for the day: ${s.distanceKm.toStringAsFixed(1)} km',
                ),
              );
            }),
        ],
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