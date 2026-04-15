import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/fleet_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/simple_bar_chart.dart';
import '../../widgets/vehicle_picker.dart';
import '../maintenance_screen.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int days = 7;

  Color _barColor(double km) {
    if (km < 70) return Colors.green;
    if (km <= 95) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final tripProvider = context.watch<TripProvider>();
    final v = fleet.selectedOrNull;

    if (v == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa có xe nào trong Firebase.')),
      );
    }

    final stats = tripProvider.persistedDailyStats(v.id, days: days);
    final runningDays = tripProvider.persistedRunningDays(v.id, days: days);

    final values = stats.map((s) => s.distanceKm).toList();
    final labels = stats.map((s) => '${s.day.day}/${s.day.month}').toList();
    final barColors = stats.map((s) => _barColor(s.distanceKm)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông số'),
        actions: [
          const VehiclePicker(),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: days,
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 ngày')),
                DropdownMenuItem(value: 30, child: Text('30 ngày')),
              ],
              onChanged: (v) => setState(() => days = v ?? 7),
            ),
          ),
          const SizedBox(width: 12),
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
            title: const Text('Bảo dưỡng'),
            subtitle: Text('Pin ${v.batteryPercent}%'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
            ),
          ),
          const Divider(),
          _MetricRow(
            leftTitle: 'Tổng quãng đường',
            leftValue: '${v.totalKm.toStringAsFixed(1)} km',
            rightTitle: 'Số ngày có chạy',
            rightValue: '$runningDays ngày',
          ),
          const SizedBox(height: 10),
          _MetricRow(
            leftTitle: 'Pin hiện tại',
            leftValue: '${v.batteryPercent} %',
            rightTitle: 'Toạ độ cuối',
            rightValue:
                '${v.lastLocation.latitude.toStringAsFixed(4)}, ${v.lastLocation.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 16),
          const Text(
            'Biểu đồ quãng đường',
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
            'Chi tiết theo ngày',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (runningDays == 0)
            const ListTile(
              dense: true,
              title: Text('Chưa có lịch sử quãng đường theo ngày'),
              subtitle: Text(
                'Khi app/web nhận totalKm, Firebase sẽ tự lưu lại dữ liệu trong tối đa 30 ngày.',
              ),
            )
          else
            ...stats.reversed.map((s) {
              final dayText = '${s.day.day}/${s.day.month}/${s.day.year}';
              return ListTile(
                dense: true,
                title: Text(dayText),
                subtitle: Text(
                  'Quãng đường trong ngày: ${s.distanceKm.toStringAsFixed(1)} km',
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
