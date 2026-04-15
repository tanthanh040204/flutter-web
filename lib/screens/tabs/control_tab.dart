import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/fleet_provider.dart';

class ControlTab extends StatelessWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final v = fleet.selectedOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều khiển'),
        actions: [
          IconButton(
            tooltip: 'Thêm xe',
            icon: const Icon(Icons.add),
            onPressed: fleet.isAddingVehicle
                ? null
                : () => _showAddVehicleDialog(context),
          ),
          const _VehiclePicker(),
          const SizedBox(width: 8),
        ],
      ),
      body: v == null
          ? _EmptyState(isSyncing: fleet.isSyncing, error: fleet.lastError)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (fleet.lastError != null) ...[
                  _InlineError(message: fleet.lastError!),
                  const SizedBox(height: 12),
                ],
                _HeroCard(
                  vehicleName: v.name,
                  odoKm: v.totalKm,
                  batteryPercent: v.batteryPercent,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SensorCard(
                        icon: Icons.thermostat,
                        title: 'Nhiệt độ',
                        value: fleet.selectedTemp == null
                            ? '--'
                            : '${fleet.selectedTemp!.toStringAsFixed(1)} °C',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SensorCard(
                        icon: Icons.water_drop,
                        title: 'Độ ẩm',
                        value: fleet.selectedHum == null
                            ? '--'
                            : '${fleet.selectedHum!.toStringAsFixed(1)} %',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SensorCard(
                        icon: Icons.air,
                        title: 'Nồng độ bụi',
                        value: fleet.selectedDust == null
                            ? '--'
                            : '${fleet.selectedDust!.toStringAsFixed(1)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Điều khiển nhanh',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SquareButton(
                        icon: v.isRunning
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        label: v.isRunning ? 'Dừng xe' : 'Chạy xe',
                        active: v.isRunning,
                        onTap: () => fleet.setRunning(!v.isRunning),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SquareButton(
                        icon: Icons.edit,
                        label: 'Đổi tên',
                        onTap: () async {
                          final name = await _askVehicleName(
                            context,
                            title: 'Đổi tên xe',
                            initial: v.name,
                          );
                          if (name != null && name.trim().isNotEmpty) {
                            await fleet.renameSelected(name.trim());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static Future<void> _showAddVehicleDialog(BuildContext context) async {
    final nameCtl = TextEditingController();
    final odoCtl = TextEditingController(text: '0');
    final batCtl = TextEditingController(text: '80');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm xe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Tên xe'),
            ),
            TextField(
              controller: odoCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tổng km hiện tại (ODO)',
              ),
            ),
            TextField(
              controller: batCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pin (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtl.text.trim();
    if (name.isEmpty) return;

    final odo = double.tryParse(odoCtl.text.trim()) ?? 0;
    final bat = int.tryParse(batCtl.text.trim()) ?? 80;

    try {
      await context.read<FleetProvider>().addVehicle(
        name: name,
        totalKm: odo,
        batteryPercent: bat,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm xe và đồng bộ lên Firebase.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể thêm xe: $e')));
      }
    }
  }

  static Future<String?> _askVehicleName(
    BuildContext context, {
    required String title,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên xe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSyncing;
  final String? error;

  const _EmptyState({required this.isSyncing, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = isSyncing
        ? 'Đang đồng bộ danh sách xe từ Firebase...'
        : 'Chưa có xe nào để hiển thị.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing) const CircularProgressIndicator(),
            if (isSyncing) const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker();

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    if (fleet.vehicles.isEmpty) return const SizedBox.shrink();

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: fleet.selectedIndex,
        items: List.generate(
          fleet.vehicles.length,
          (i) =>
              DropdownMenuItem(value: i, child: Text(fleet.vehicles[i].name)),
        ),
        onChanged: (i) {
          if (i != null) context.read<FleetProvider>().selectVehicle(i);
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String vehicleName;
  final double odoKm;
  final int batteryPercent;

  const _HeroCard({
    required this.vehicleName,
    required this.odoKm,
    required this.batteryPercent,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeWidth = (constraints.maxWidth * 0.33)
            .clamp(300.0, 500.0)
            .toDouble();

        return Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primary.withOpacity(0.98), primary.withOpacity(0.58)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  left: -40,
                  bottom: -40,
                  child: _GlowCircle(size: 180, opacity: 0.05),
                ),
                Positioned(
                  right: -30,
                  top: -30,
                  child: _GlowCircle(size: 220, opacity: 0.06),
                ),
                Positioned(
                  left: 22,
                  top: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tổng: ${odoKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: timeWidth,
                    height: 138,
                    child: const _LiveDateTimeCard(),
                  ),
                ),
                const Positioned(
                  right: 18,
                  top: 14,
                  child: _VehicleLogoBadge(),
                ),
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: _BatteryPill(percent: batteryPercent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _LiveDateTimeCard extends StatefulWidget {
  const _LiveDateTimeCard();

  @override
  State<_LiveDateTimeCard> createState() => _LiveDateTimeCardState();
}

class _LiveDateTimeCardState extends State<_LiveDateTimeCard> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final date = '${_two(_now.day)}/${_two(_now.month)}/${_now.year}';
    final time = '${_two(_now.hour)}:${_two(_now.minute)}:${_two(_now.second)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.09),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date,
              style: TextStyle(
                color: Colors.white.withOpacity(0.96),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withOpacity(0.98),
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleLogoBadge extends StatelessWidget {
  const _VehicleLogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Center(
        child: Icon(
          Icons.electric_scooter,
          size: 98,
          color: Colors.white.withOpacity(0.92),
        ),
      ),
    );
  }
}

class _BatteryPill extends StatelessWidget {
  final int percent;

  const _BatteryPill({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.battery_full, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SensorCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
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

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.green;
    final bg = active
        ? activeColor.withOpacity(0.14)
        : Theme.of(context).colorScheme.surface;
    final border = active ? activeColor.withOpacity(0.40) : Colors.transparent;
    final fg = active ? activeColor : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: fg),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
