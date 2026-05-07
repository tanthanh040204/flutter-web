// @file       maintenance_screen.dart
// @brief      Screen UI for Maintenance.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fleet_provider.dart';
import '../providers/maintenance_provider.dart';

/* Public classes ----------------------------------------------------- */
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
        title: const Text('Maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset total distance on all devices',
            onPressed: () => _confirmClearTotalDistance(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItem(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.6),
                      width: 1.2,
                    )
                  : null,
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
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Need maintenance',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Cycle: ${it.cycleKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: due ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
                Text(
                  'Travelled: ${it.maintanceKm.toStringAsFixed(0)} km',
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
                        label: const Text('Edit Cycle'),
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
                            SnackBar(content: Text('Updated: ${it.name}')),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Mark as Serviced'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearTotalDistance(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset total distance?'),
        content: const Text(
          'CLEAR_TOTAL_DISTANCE will be sent to every device. Each device\'s '
          'total km will reset to 0 once it acknowledges with OK.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final sent = context.read<FleetProvider>().clearTotalDistance();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'CLEAR_TOTAL_DISTANCE sent. Waiting for OK from devices...'
              : 'Could not send command (MQTT not connected or no devices).',
        ),
      ),
    );
  }

  Future<void> _showAddItem(BuildContext context) async {
    final fleet = context.read<FleetProvider>();
    final maintenance = context.read<MaintenanceProvider>();
    final v = fleet.selected;

    final nameCtl = TextEditingController();
    final kmCtl = TextEditingController(text: '2000');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Maintenance Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Name (e.g., Tire Replacement)',
              ),
            ),
            TextField(
              controller: kmCtl,
              decoration: const InputDecoration(labelText: 'Cycle (km)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtl.text.trim();
    final cycleKm = double.tryParse(kmCtl.text.trim()) ?? 0;
    if (name.isEmpty || cycleKm <= 0) return;

    await maintenance.addItem(v.id, name: name, cycleKm: cycleKm);
  }

  Future<void> _showEditCycleKm(
    BuildContext context,
    String itemId,
    double current,
  ) async {
    final fleet = context.read<FleetProvider>();
    final maintenance = context.read<MaintenanceProvider>();
    final v = fleet.selected;

    final kmCtl = TextEditingController(text: current.toStringAsFixed(0));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Cycle (km)'),
        content: TextField(
          controller: kmCtl,
          decoration: const InputDecoration(labelText: 'Cycle (km)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final cycleKm = double.tryParse(kmCtl.text.trim()) ?? current;
    if (cycleKm <= 0) return;

    await maintenance.updateCycleKm(v.id, itemId, cycleKm);
  }
}

/* End of file -------------------------------------------------------- */
