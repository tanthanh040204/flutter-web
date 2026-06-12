// @file       overview_tab.dart
// @brief      Fleet overview: vehicle count and per-vehicle status cards.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/rental_provider.dart';

/* Public classes ----------------------------------------------------- */
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final rental = context.watch<RentalProvider>();
    final devices = context.watch<DeviceProvider>();
    final vehicles = fleet.vehicles;
    final rentingCount = vehicles
        .where((v) => rental.isBikeRented(v.id))
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Tổng quan', 'Overview'))),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: vehicles.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.pedal_bike, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Chưa có xe nào', 'No vehicles yet'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SummaryCard(
                      totalCount: vehicles.length,
                      rentingCount: rentingCount,
                    );
                  }
                  final v = vehicles[index - 1];
                  return _VehicleCard(
                    vehicle: v,
                    renting: rental.isBikeRented(v.id),
                    paused: rental.isBikePaused(v.id),
                    online: devices.deviceById(v.id)?.online ?? false,
                    lowBattery: fleet.isLowBattery(v.id),
                  );
                },
              ),
      ),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalCount, required this.rentingCount});

  final int totalCount;
  final int rentingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryStat(
              icon: Icons.pedal_bike,
              color: Colors.blue,
              label: context.tr('Tổng số xe', 'Total vehicles'),
              value: '$totalCount',
            ),
            const SizedBox(width: 24),
            _SummaryStat(
              icon: Icons.directions_bike,
              color: Colors.green,
              label: context.tr('Đang được thuê', 'Currently rented'),
              value: '$rentingCount',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final MaterialColor color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color.shade700),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.renting,
    required this.paused,
    required this.online,
    required this.lowBattery,
  });

  final Vehicle vehicle;
  final bool renting;
  final bool paused;
  final bool online;
  final bool lowBattery;

  @override
  Widget build(BuildContext context) {
    final status = _status(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: status.color.shade50,
                  child: Icon(Icons.pedal_bike, color: status.color.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.label,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                if (lowBattery) ...[
                  _StatusPill(
                    color: Colors.red,
                    label: context.tr('Pin yếu', 'Low battery'),
                  ),
                  const SizedBox(width: 8),
                ],
                _OnlineDot(online: online),
                const SizedBox(width: 8),
                _StatusPill(color: status.color, label: status.label),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.qr_code,
              label: context.tr('Mã xe', 'Vehicle ID'),
              value: vehicle.id,
            ),
            _InfoRow(
              icon: online ? Icons.wifi : Icons.wifi_off,
              label: context.tr('Kết nối', 'Connection'),
              value: online
                  ? context.tr('Trực tuyến', 'Online')
                  : context.tr('Ngoại tuyến', 'Offline'),
            ),
            _InfoRow(
              icon: lowBattery ? Icons.battery_alert : Icons.battery_full,
              label: context.tr('Pin', 'Battery'),
              value: lowBattery
                  ? context.tr(
                      '${vehicle.batteryPercent}% · Yếu pin',
                      '${vehicle.batteryPercent}% · Low',
                    )
                  : '${vehicle.batteryPercent}%',
            ),
            _InfoRow(
              icon: Icons.speed,
              label: context.tr('Tốc độ hiện tại', 'Current speed'),
              value: '${vehicle.velocityKmh.toStringAsFixed(1)} km/h',
            ),
            _InfoRow(
              icon: Icons.route,
              label: context.tr('Tổng quãng đường', 'Total distance'),
              value: '${vehicle.totalKm.toStringAsFixed(1)} km',
            ),
            _InfoRow(
              icon: vehicle.isLocked ? Icons.lock : Icons.lock_open,
              label: context.tr('Khóa xe', 'Lock'),
              value: vehicle.isLocked
                  ? context.tr('Đã khóa', 'Locked')
                  : context.tr('Đã mở khóa', 'Unlocked'),
            ),
            _InfoRow(
              icon: Icons.schedule,
              label: context.tr('Cập nhật lúc', 'Updated at'),
              value: _dateTime(vehicle.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  _VehicleStatus _status(BuildContext context) {
    if (renting) {
      return paused
          ? _VehicleStatus(Colors.orange, context.tr('Tạm dừng', 'Paused'))
          : _VehicleStatus(Colors.blue, context.tr('Đang thuê', 'Rented'));
    }
    if (vehicle.isRunning) {
      return _VehicleStatus(Colors.green, context.tr('Đang chạy', 'Running'));
    }
    if (vehicle.isLocked) {
      return _VehicleStatus(Colors.blueGrey, context.tr('Đã khóa', 'Locked'));
    }
    return _VehicleStatus(Colors.teal, context.tr('Sẵn sàng', 'Available'));
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _VehicleStatus {
  const _VehicleStatus(this.color, this.label);

  final MaterialColor color;
  final String label;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : Colors.grey;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color.shade500, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final MaterialColor color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
