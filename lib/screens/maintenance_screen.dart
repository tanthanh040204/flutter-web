import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fleet_provider.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final v = fleet.selected;
    final maint = context.watch<MaintenanceProvider>();
    final items = maint.itemsOf(v.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo dưỡng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItem(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          final due = it.isDue;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
              border: due
                  ? Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.6),
                      width: 1.2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        it.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: due
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                    if (due)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Cần bảo dưỡng',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Chu kỳ: ${it.cycleKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: due ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
                Text(
                  'Đã đi: ${it.maintanceKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: due ? Theme.of(context).colorScheme.error : null,
                    fontWeight: due ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showEditCycleKm(context, it.id, it.cycleKm),
                        icon: const Icon(Icons.edit),
                        label: const Text('Sửa chu kỳ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await context
                              .read<MaintenanceProvider>()
                              .markServiced(v.id, it.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã cập nhật: ${it.name}')),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Đã thay'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddItem(BuildContext context) async {
    final fleet = context.read<FleetProvider>();
    final v = fleet.selected;

    final nameCtl = TextEditingController();
    final kmCtl = TextEditingController(text: '2000');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm hạng mục bảo dưỡng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Tên (vd: Thay lốp)'),
            ),
            TextField(
              controller: kmCtl,
              decoration: const InputDecoration(labelText: 'Chu kỳ (km)'),
              keyboardType: TextInputType.number,
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
    final cycleKm = double.tryParse(kmCtl.text.trim()) ?? 0;
    if (name.isEmpty || cycleKm <= 0) return;

    await context.read<MaintenanceProvider>().addItem(
          v.id,
          name: name,
          cycleKm: cycleKm,
        );
  }

  Future<void> _showEditCycleKm(
    BuildContext context,
    String itemId,
    double current,
  ) async {
    final fleet = context.read<FleetProvider>();
    final v = fleet.selected;

    final kmCtl = TextEditingController(text: current.toStringAsFixed(0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sửa chu kỳ (km)'),
        content: TextField(
          controller: kmCtl,
          decoration: const InputDecoration(labelText: 'Chu kỳ (km)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final cycleKm = double.tryParse(kmCtl.text.trim()) ?? current;
    if (cycleKm <= 0) return;

    await context.read<MaintenanceProvider>().updateCycleKm(
          v.id,
          itemId,
          cycleKm,
        );
  }
}
