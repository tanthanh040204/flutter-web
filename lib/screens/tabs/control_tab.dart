// @file       control_tab.dart
// @brief      Tab UI for Control.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/device_state.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/vehicle_picker.dart';

/* Public classes ----------------------------------------------------- */
class ControlTab extends StatelessWidget {
  const ControlTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final v = fleet.selectedOrNull;

    // Real-time device state for lock status and online indicator
    final deviceProvider = context.watch<DeviceProvider>();
    final device = v != null ? deviceProvider.deviceById(v.id) : null;

    final tripM = device?.latest?.distanceM;
    final controlTripKmStr = tripM == null
        ? '--'
        : '${(tripM / 1000.0).toStringAsFixed(2)} km';
    final velLive = fleet.selectedVelocityKmh;
    final controlSpeedStr = velLive == null
        ? '--'
        : '${velLive.toStringAsFixed(1)} km/h';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Điều khiển', 'Control')),
        actions: [
          IconButton(
            tooltip: context.tr('Thêm xe mới', 'Add new vehicle'),
            icon: const Icon(Icons.add),
            onPressed: fleet.isAddingVehicle
                ? null
                : () => _showAddVehicleDialog(context),
          ),
          const VehiclePicker(),
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
                  online: device?.online ?? false,
                  lockState: device?.lockState,
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.thermostat,
                            title: context.tr('Nhiệt độ', 'Temperature'),
                            value: fleet.selectedTemp == null
                                ? '--'
                                : '${fleet.selectedTemp!.toStringAsFixed(1)} °C',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.water_drop,
                            title: context.tr('Độ ẩm', 'Humidity'),
                            value: fleet.selectedHum == null
                                ? '--'
                                : '${fleet.selectedHum!.toStringAsFixed(1)} %',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.air,
                            title: context.tr('Bụi', 'Dust value'),
                            value: fleet.selectedDust == null
                                ? '--'
                                : fleet.selectedDust!.toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.speed,
                            title: context.tr('Tốc độ', 'Speed'),
                            value: controlSpeedStr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.route,
                            title: context.tr('Quãng đường chuyến', 'Trip distance'),
                            value: controlTripKmStr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('Điều khiển nhanh', 'Quick Control'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Lock / Unlock / Resume — LOCK or UNLOCK from device state; waits for OK (30 s)
                    Expanded(child: _InlockButton(vehicleId: v.id)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SquareButton(
                        icon: Icons.edit,
                        label: context.tr('Sửa tên', 'Edit Name'),
                        onTap: () async {
                          final name = await _askVehicleName(
                            context,
                            title: context.tr('Sửa tên xe', 'Edit Vehicle Name'),
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

  // Dialog accepts 3-digit vehicle number; ID becomes haq-trk-xxx.
  static Future<void> _showAddVehicleDialog(BuildContext context) async {
    final numCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Thêm xe mới', 'Add New Vehicle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Nhập số xe gồm 3 chữ số.\nID sẽ là: haq-trk-XXX', 'Enter 3-digit vehicle number.\nID will be: haq-trk-XXX'),
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numCtl,
              keyboardType: TextInputType.number,
              maxLength: 3,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: context.tr('Số xe (ví dụ: 001)', 'Vehicle Number (e.g. 001)'),
                prefixText: 'haq-trk-',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Thêm', 'Add')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final number = numCtl.text.trim().padLeft(3, '0');
    if (number.isEmpty || number.length != 3) return;

    try {
      await context.read<FleetProvider>().addVehicle(vehicleNumber: number);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Đã thêm haq-trk-$number vào Firebase.', 'Added haq-trk-$number to Firebase.'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Không thể thêm xe: $e', 'Cannot add vehicle: $e'))));
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
          decoration: InputDecoration(labelText: context.tr('Tên xe', 'Vehicle Name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.tr('Lưu', 'Save')),
          ),
        ],
      ),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _EmptyState extends StatelessWidget {
  final bool isSyncing;
  final String? error;

  const _EmptyState({required this.isSyncing, required this.error});

  @override
  Widget build(BuildContext context) {
    final message = isSyncing
        ? context.tr('Đang thêm xe mới...', 'Adding new vehicle...')
        : context.tr('Chưa có xe để hiển thị.', 'No vehicles to display.');

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
  final bool online;
  final DeviceLockState? lockState;

  const _HeroCard({
    required this.vehicleName,
    required this.odoKm,
    required this.batteryPercent,
    this.online = false,
    this.lockState,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Online/Offline dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: online
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            online ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                          if (lockState != null) ...[
                            const SizedBox(width: 10),
                            _LockStateBadge(state: lockState!),
                          ],
                        ],
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

// Small badge showing Active / Locked / Pause state.
class _LockStateBadge extends StatelessWidget {
  final DeviceLockState state;
  const _LockStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      DeviceLockState.active => (context.tr('Đang hoạt động', 'Active'), Colors.greenAccent),
      DeviceLockState.locked => (context.tr('Đang khóa', 'Locked'), Colors.redAccent),
      DeviceLockState.pause => (context.tr('Tạm dừng', 'Pause'), Colors.orangeAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Lock / Unlock / Resume — DeviceProvider.sendUnlock maps state → LOCK or UNLOCK; waits for OK (30 s).
class _InlockButton extends StatefulWidget {
  final String vehicleId;
  const _InlockButton({required this.vehicleId});

  @override
  State<_InlockButton> createState() => _InlockButtonState();
}

class _InlockButtonState extends State<_InlockButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    final deviceProvider = context.read<DeviceProvider>();
    final device = deviceProvider.deviceById(widget.vehicleId);
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Không tìm thấy thiết bị trong MQTT.', 'Device not found in MQTT registry.'))),
      );
      return;
    }

    setState(() => _loading = true);
    final ok = await deviceProvider.sendUnlock(widget.vehicleId);
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('Thiết bị đã xác nhận lệnh.', 'Command acknowledged by device.')
              : context.tr('Không có phản hồi - hết thời gian chờ (30 giây).', 'No response - timeout (30 s).'),
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final device = deviceProvider.deviceById(widget.vehicleId);
    final lockState = device?.lockState ?? DeviceLockState.locked;
    final isPending = deviceProvider.isPendingLock(widget.vehicleId);

    final isLocked = lockState == DeviceLockState.locked;
    final isPause = lockState == DeviceLockState.pause;
    final icon = _loading || isPending
        ? Icons.hourglass_top
        : (isLocked
              ? Icons.lock_open
              : isPause
              ? Icons.play_circle_outline
              : Icons.lock);
    final label = _loading || isPending
        ? context.tr('Đang chờ...', 'Waiting...')
        : (isLocked
              ? context.tr('Mở khóa', 'Unlock')
              : isPause
              ? context.tr('Tiếp tục', 'Resume')
              : context.tr('Khóa', 'Lock'));

    final bg = (isLocked || isPause)
        ? Colors.orange.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.12);
    final fg = (isLocked || isPause)
        ? Colors.orange.shade700
        : Colors.red.shade600;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: (_loading || isPending) ? null : _onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
          border: Border.all(color: fg.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading || isPending)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
              )
            else
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

/* End of file -------------------------------------------------------- */
