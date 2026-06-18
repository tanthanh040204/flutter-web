// @file       notifications_tab.dart
// @brief      Tab UI for Notifications.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../models/app_notification.dart';
import '../../models/device_state.dart';
import '../../providers/device_provider.dart';
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

  // Top filter: all | help | login | maintenance.
  String _filter = 'all';

  Widget _buildFilterBar(BuildContext context) {
    final filters = <(String, String)>[
      ('all', context.tr('Tất cả', 'All')),
      ('help', context.tr('Cứu trợ', 'Help')),
      ('login', context.tr('Đăng nhập', 'Login')),
      ('maintenance', context.tr('Bảo trì', 'Maintenance')),
    ];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final (key, label) in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == key,
                onSelected: (_) => setState(() => _filter = key),
              ),
            ),
        ],
      ),
    );
  }

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
    final allVisibleSelected =
        items.isNotEmpty && selectedCount == items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCount == 0
                    ? context.tr(
                        'Chọn thông báo cần xóa',
                        'Select notifications to delete',
                      )
                    : context.tr(
                        'Đã chọn $selectedCount thông báo',
                        '$selectedCount notifications selected',
                      ),
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
              icon: Icon(
                allVisibleSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              label: Text(
                context.tr(
                  allVisibleSelected ? 'Bỏ chọn' : 'Chọn tất cả',
                  allVisibleSelected ? 'Unselect' : 'Select all',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0 || _isDeleting
                  ? null
                  : _deleteSelected,
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
    final deviceProvider = context.watch<DeviceProvider>();

    final showHelp = _filter == 'all' || _filter == 'help';
    final showLogin = _filter == 'all' || _filter == 'login';
    final showMaint = _filter == 'all' || _filter == 'maintenance';

    final maintenanceMessages = <String>[];
    if (showMaint) {
      for (final v in fleet.vehicles) {
        maintenanceMessages.addAll(maint.dueMessagesForVehicle(v));
      }
    }

    final List<DeviceState> helpDevices = showHelp
        ? deviceProvider.devices.where((d) => d.helpRequested).toList()
        : const <DeviceState>[];

    final List<DeviceState> lowBatteryDevices = showMaint
        ? deviceProvider.devices.where((d) => d.lowBattery).toList()
        : const <DeviceState>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc(AppStrings.titleNotifications)),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: StreamBuilder<List<AppNotificationItem>>(
              stream: FirebaseRepo.instance.watchAppNotifications(limit: 200),
              builder: (context, snapshot) {
                final visibleLoginNotifications = showLogin
                    ? (snapshot.data ?? const <AppNotificationItem>[])
                          .where(
                            (item) => !_hiddenDeletedNotificationIds.contains(
                              item.id,
                            ),
                          )
                          .toList()
                    : const <AppNotificationItem>[];

                _selectedNotificationIds.removeWhere(
                  (id) =>
                      !visibleLoginNotifications.any((item) => item.id == id),
                );

                final hasAny =
                    helpDevices.isNotEmpty ||
                    visibleLoginNotifications.isNotEmpty ||
                    maintenanceMessages.isNotEmpty ||
                    lowBatteryDevices.isNotEmpty;

                if (!hasAny) {
                  return Center(
                    child: Text(
                      context.tr('Chưa có thông báo.', 'No notifications.'),
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (helpDevices.isNotEmpty) ...[
                          Text(
                            context.tr('Yêu cầu cứu trợ', 'Help Requests'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...helpDevices.map(
                            (d) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: Colors.red.shade50,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.sos,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  context.tr(
                                    'Yêu cầu cứu trợ từ ${d.id}',
                                    'Help requested from ${d.id}',
                                  ),
                                ),
                                subtitle: Text(
                                  context.tr(
                                    'Người dùng đã giữ nút SOS',
                                    'User held the SOS button',
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: context.tr(
                                    'Tắt cảnh báo',
                                    'Dismiss alarm',
                                  ),
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    context.read<DeviceProvider>().clearHelp(
                                      d.id,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.tr(
                                            'Đã tắt cảnh báo.',
                                            'Alarm dismissed.',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (visibleLoginNotifications.isNotEmpty) ...[
                          Text(
                            context.tr(
                              'Đăng nhập gần đây',
                              'Recently Logged In',
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBulkToolbar(visibleLoginNotifications),
                          ...visibleLoginNotifications.map((item) {
                            final selected = _selectedNotificationIds.contains(
                              item.id,
                            );
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
                                              _selectedNotificationIds.add(
                                                item.id,
                                              );
                                            } else {
                                              _selectedNotificationIds.remove(
                                                item.id,
                                              );
                                            }
                                          });
                                        },
                                ),
                                title: Text(
                                  _notificationMessage(context, item),
                                ),
                                subtitle: Text(_formatDateTime(item.createdAt)),
                                onTap: _isDeleting
                                    ? null
                                    : () {
                                        setState(() {
                                          if (selected) {
                                            _selectedNotificationIds.remove(
                                              item.id,
                                            );
                                          } else {
                                            _selectedNotificationIds.add(
                                              item.id,
                                            );
                                          }
                                        });
                                      },
                                trailing: IconButton(
                                  tooltip: context.tr(
                                    'Xóa thông báo',
                                    'Delete notification',
                                  ),
                                  icon: const Icon(Icons.close),
                                  onPressed: _isDeleting
                                      ? null
                                      : () async {
                                          setState(() {
                                            _isDeleting = true;
                                            _hiddenDeletedNotificationIds.add(
                                              item.id,
                                            );
                                          });

                                          try {
                                            await FirebaseRepo.instance
                                                .deleteAppNotification(item.id);
                                            if (!context.mounted) return;
                                            setState(() {
                                              _selectedNotificationIds.remove(
                                                item.id,
                                              );
                                              _isDeleting = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.tr(
                                                    'Đã xóa thông báo.',
                                                    'Notification deleted.',
                                                  ),
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            setState(() {
                                              _hiddenDeletedNotificationIds
                                                  .remove(item.id);
                                              _isDeleting = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.tr(
                                                    'Không xóa được thông báo: $e',
                                                    'Could not delete notification: $e',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],
                        if (maintenanceMessages.isNotEmpty ||
                            lowBatteryDevices.isNotEmpty) ...[
                          Text(
                            context.tr('Bảo trì', 'Maintenance'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...lowBatteryDevices.map(
                            (d) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: Colors.red.shade50,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.battery_alert,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  context.tr(
                                    'Pin yếu - ${d.id}',
                                    'Low battery - ${d.id}',
                                  ),
                                ),
                                subtitle: Text(
                                  context.tr(
                                    'Thiết bị báo pin yếu, cần kiểm tra/sạc.',
                                    'Device reported a low battery; check or charge it.',
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: context.tr(
                                    'Tắt cảnh báo',
                                    'Dismiss alarm',
                                  ),
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    context
                                        .read<DeviceProvider>()
                                        .clearLowBattery(d.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.tr(
                                            'Đã tắt cảnh báo.',
                                            'Alarm dismissed.',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (maintenanceMessages.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                context.tr(
                                  'Thông báo bảo trì được tạo từ số km bảo dưỡng, không phải bản ghi riêng trong Firebase.',
                                  'Maintenance warnings are generated from service mileage, not separate Firebase records.',
                                ),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
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
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
