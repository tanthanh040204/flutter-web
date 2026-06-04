// @file       notifications_tab.dart
// @brief      Tab UI for Notifications.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../models/app_notification.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../services/firebase_repo.dart';
import '../../widgets/vehicle_picker.dart';

/* Public classes ----------------------------------------------------- */
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

/* Private classes ---------------------------------------------------- */
class _NotificationsTabState extends State<NotificationsTab> {
  final Set<String> _selectedNotificationIds = <String>{};
  final Set<String> _hiddenDeletedNotificationIds = <String>{};
  bool _isDeleting = false;

  String _formatDateTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final mo = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    return '$h:$m - $d/$mo/$y';
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedNotificationIds.toList(growable: false);
    if (ids.isEmpty || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _hiddenDeletedNotificationIds.addAll(ids);
    });

    try {
      await FirebaseRepo.instance.deleteAppNotifications(ids);
      if (!mounted) return;
      setState(() {
        _selectedNotificationIds.removeAll(ids);
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Đã xóa ${ids.length} thông báo đã chọn.',
              '${ids.length} selected notifications deleted.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiddenDeletedNotificationIds.removeAll(ids);
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Không xóa được thông báo: $e',
              'Could not delete notifications: $e',
            ),
          ),
        ),
      );
    }
  }


  String _notificationMessage(BuildContext context, AppNotificationItem item) {
    if (item.type == 'login' && (item.employeeCode ?? '').isNotEmpty) {
      final h = item.createdAt.hour.toString().padLeft(2, '0');
      final m = item.createdAt.minute.toString().padLeft(2, '0');
      return context.tr(
        'Mã nhân viên ${item.employeeCode} đã đăng nhập lúc $h:$m',
        'Employee code ${item.employeeCode} has logged in at $h:$m',
      );
    }
    return item.message;
  }

  Widget _buildBulkToolbar(List<AppNotificationItem> items) {
    final ids = items.map((item) => item.id).toSet();
    final selectedCount = _selectedNotificationIds.where(ids.contains).length;
    final allVisibleSelected = items.isNotEmpty && selectedCount == items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCount == 0
                    ? context.tr('Chọn thông báo cần xóa', 'Select notifications to delete')
                    : context.tr('Đã chọn $selectedCount thông báo', '$selectedCount notifications selected'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _isDeleting || items.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (allVisibleSelected) {
                          _selectedNotificationIds.removeAll(ids);
                        } else {
                          _selectedNotificationIds.addAll(ids);
                        }
                      });
                    },
              icon: Icon(allVisibleSelected ? Icons.check_box : Icons.check_box_outline_blank),
              label: Text(
                context.tr(
                  allVisibleSelected ? 'Bỏ chọn' : 'Chọn tất cả',
                  allVisibleSelected ? 'Unselect' : 'Select all',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0 || _isDeleting ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text(context.tr('Xóa đã chọn', 'Delete selected')),
            ),
          ],
        ),
      ),
    );
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
        title: Text(context.loc(AppStrings.titleNotifications)),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: StreamBuilder<List<AppNotificationItem>>(
        stream: FirebaseRepo.instance.watchAppNotifications(limit: 200),
        builder: (context, snapshot) {
          final visibleLoginNotifications =
              (snapshot.data ?? const <AppNotificationItem>[])
                  .where((item) => !_hiddenDeletedNotificationIds.contains(item.id))
                  .toList();

          _selectedNotificationIds.removeWhere(
            (id) => !visibleLoginNotifications.any((item) => item.id == id),
          );

          final hasAny =
              visibleLoginNotifications.isNotEmpty || maintenanceMessages.isNotEmpty;

          if (!hasAny) {
            return Center(child: Text(context.tr('Chưa có thông báo.', 'No notifications.')));
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (visibleLoginNotifications.isNotEmpty) ...[
                    Text(
                      context.tr('Đăng nhập gần đây', 'Recently Logged In'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildBulkToolbar(visibleLoginNotifications),
                    ...visibleLoginNotifications.map(
                      (item) {
                        final selected = _selectedNotificationIds.contains(item.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Checkbox(
                              value: selected,
                              onChanged: _isDeleting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedNotificationIds.add(item.id);
                                        } else {
                                          _selectedNotificationIds.remove(item.id);
                                        }
                                      });
                                    },
                            ),
                            title: Text(_notificationMessage(context, item)),
                            subtitle: Text(_formatDateTime(item.createdAt)),
                            onTap: _isDeleting
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selectedNotificationIds.remove(item.id);
                                      } else {
                                        _selectedNotificationIds.add(item.id);
                                      }
                                    });
                                  },
                            trailing: IconButton(
                              tooltip: context.tr('Xóa thông báo', 'Delete notification'),
                              icon: const Icon(Icons.close),
                              onPressed: _isDeleting
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isDeleting = true;
                                        _hiddenDeletedNotificationIds.add(item.id);
                                      });

                                      try {
                                        await FirebaseRepo.instance.deleteAppNotification(item.id);
                                        if (!context.mounted) return;
                                        setState(() {
                                          _selectedNotificationIds.remove(item.id);
                                          _isDeleting = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(context.tr('Đã xóa thông báo.', 'Notification deleted.')),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        setState(() {
                                          _hiddenDeletedNotificationIds.remove(item.id);
                                          _isDeleting = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(context.tr('Không xóa được thông báo: $e', 'Could not delete notification: $e')),
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (maintenanceMessages.isNotEmpty) ...[
                    Text(
                      context.tr('Bảo trì', 'Maintenance'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.tr(
                          'Thông báo bảo trì được tạo từ số km bảo dưỡng, không phải bản ghi riêng trong Firebase.',
                          'Maintenance warnings are generated from service mileage, not separate Firebase records.',
                        ),
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ),
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
              ),
              if (_isDeleting)
                Container(
                  color: Colors.black.withOpacity(0.06),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
