// @file       notifications_tab.dart
// @brief      Tab UI for Notifications.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../services/firebase_repo.dart';
import '../../utils/date_utils.dart';
import '../../widgets/vehicle_picker.dart';

/* Public classes ----------------------------------------------------- */
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final maint = context.watch<MaintenanceProvider>();
    final deviceProvider = context.watch<DeviceProvider>();

    final maintenanceMessages = <String>[];
    for (final v in fleet.vehicles) {
      maintenanceMessages.addAll(maint.dueMessagesForVehicle(v));
    }

    final helpDevices =
        deviceProvider.devices.where((d) => d.helpRequested).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<List<AppNotificationItem>>(
        stream: FirebaseRepo.instance.watchAppNotifications(limit: 50),
        builder: (context, snapshot) {
          final loginNotifications =
              snapshot.data ?? const <AppNotificationItem>[];
          final hasAny =
              helpDevices.isNotEmpty ||
              loginNotifications.isNotEmpty ||
              maintenanceMessages.isNotEmpty;

          if (!hasAny) {
            return const Center(child: Text('No notifications.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (helpDevices.isNotEmpty) ...[
                const Text(
                  'Help Requests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...helpDevices.map(
                  (d) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.sos, color: Colors.red),
                      title: Text('Help requested from ${d.id}'),
                      subtitle: const Text('User held the SOS button'),
                      trailing: IconButton(
                        tooltip: 'Dismiss alarm',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          context.read<DeviceProvider>().clearHelp(d.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alarm dismissed.')),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (loginNotifications.isNotEmpty) ...[
                const Text(
                  'Recently Logged In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...loginNotifications.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.login, color: Colors.green),
                      title: Text(item.message),
                      subtitle: Text(
                        AppDateUtils.formatShortDateTime(item.createdAt),
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete notification',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await FirebaseRepo.instance.deleteAppNotification(
                            item.id,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notification deleted.'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (maintenanceMessages.isNotEmpty) ...[
                const Text(
                  'Maintenance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...maintenanceMessages.map(
                  (message) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(
                        Icons.notifications_active,
                        color: Colors.orange,
                      ),
                      title: Text(message),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
