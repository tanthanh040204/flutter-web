import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../services/firebase_repo.dart';
import '../../widgets/vehicle_picker.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  String _formatDateTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final mo = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    return '$h:$m - $d/$mo/$y';
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final maint = context.watch<MaintenanceProvider>();

    final maintenanceMessages = <String>[];
    for (final v in fleet.vehicles) {
      maintenanceMessages.addAll(maint.dueMessagesForVehicle(v));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<List<AppNotificationItem>>(
        stream: FirebaseRepo.instance.watchAppNotifications(limit: 50),
        builder: (context, snapshot) {
          final loginNotifications =
              snapshot.data ?? const <AppNotificationItem>[];
          final hasAny =
              loginNotifications.isNotEmpty || maintenanceMessages.isNotEmpty;

          if (!hasAny) {
            return const Center(child: Text('Chưa có thông báo.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (loginNotifications.isNotEmpty) ...[
                const Text(
                  'Đăng nhập gần đây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...loginNotifications.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.login, color: Colors.green),
                      title: Text(item.message),
                      subtitle: Text(_formatDateTime(item.createdAt)),
                      trailing: IconButton(
                        tooltip: 'Xóa thông báo',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await FirebaseRepo.instance.deleteAppNotification(
                            item.id,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã xóa thông báo đăng nhập.'),
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
                  'Bảo dưỡng',
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
