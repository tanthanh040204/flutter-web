// @file       user_tab.dart
// @brief      Shows mobile users who are currently renting vehicles.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../models/rental_user_info.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/rental_provider.dart';
import '../../services/firebase_repo.dart';

/* Public classes ----------------------------------------------------- */
class UserTab extends StatelessWidget {
  const UserTab({super.key});

  @override
  Widget build(BuildContext context) {
    final rentals = context.watch<RentalProvider>().activeRentals;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc(AppStrings.titleUsers)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: rentals.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.person_search,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      'Chưa có người dùng nào đang thuê xe',
                      'No active rental users yet',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Khi người dùng quét QR và mở khóa xe thành công, thông tin người dùng và thời gian bắt đầu thuê sẽ hiện ở đây.',
                      'When a user scans a QR code and unlocks a vehicle successfully, their profile and rental start time will appear here.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rentals.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SummaryCard(activeCount: rentals.length);
                  }
                  return _ActiveRentalCard(rental: rentals[index - 1]);
                },
              ),
      ),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.people_alt, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Tổng phiên thuê đang chạy', 'Current active rentals'),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeCount',
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
      ),
    );
  }
}

class _ActiveRentalCard extends StatelessWidget {
  const _ActiveRentalCard({required this.rental});

  final ActiveRental rental;

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final vehicleName = _vehicleName(fleet, rental.bikeId);

    return FutureBuilder<RentalUserInfo?>(
      future: FirebaseRepo.instance.getRentalUserInfo(rental.userId),
      builder: (context, snap) {
        final user = snap.data;
        final loading = snap.connectionState == ConnectionState.waiting;
        final title = loading
            ? context.tr('Đang tải thông tin người dùng...', 'Loading user info...')
            : user?.displayName ?? rental.userId;

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
                      backgroundColor: Colors.green.shade50,
                      child: Icon(Icons.person, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('Đang sử dụng $vehicleName', 'Using $vehicleName'),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(label: context.tr('Đang thuê', 'Active')),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _InfoTile(
                      icon: Icons.qr_code,
                      label: context.tr('Mã user MQTT', 'MQTT user ID'),
                      value: rental.userId,
                    ),
                    _InfoTile(
                      icon: Icons.badge,
                      label: context.tr('Mã nhân viên', 'Employee code'),
                      value: user?.employeeCode ?? '--',
                    ),
                    _InfoTile(
                      icon: Icons.email,
                      label: 'Email',
                      value: user?.email ?? '--',
                    ),
                    _InfoTile(
                      icon: Icons.phone,
                      label: context.tr('Số điện thoại', 'Phone'),
                      value: user?.phone ?? '--',
                    ),
                    _InfoTile(
                      icon: Icons.account_balance_wallet,
                      label: context.tr('Số dư hiện tại', 'Current balance'),
                      value: _money(user?.balance ?? 0),
                    ),
                    _InfoTile(
                      icon: Icons.lock_clock,
                      label: context.tr('Tiền cọc đang giữ', 'Deposit locked'),
                      value: _money(user?.depositLocked ?? 0),
                    ),
                    _InfoTile(
                      icon: Icons.pedal_bike,
                      label: context.tr('Mã xe', 'Vehicle ID'),
                      value: rental.bikeId,
                    ),
                    _InfoTile(
                      icon: Icons.schedule,
                      label: context.tr('Bắt đầu thuê', 'Rental started at'),
                      value: _dateTime(rental.startTime),
                    ),
                    _InfoTile(
                      icon: Icons.timer,
                      label: context.tr('Thời lượng hiện tại', 'Current duration'),
                      value: _duration(DateTime.now().difference(rental.startTime)),
                    ),
                    _InfoTile(
                      icon: Icons.payments,
                      label: context.tr('Đã trừ', 'Charged'),
                      value: _money(rental.chargedTokens),
                    ),
                  ],
                ),
                if (snap.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Không đọc được hồ sơ người dùng từ Firebase. Web vẫn hiển thị userId từ MQTT.',
                      'Could not read the user profile from Firebase. The web still shows the MQTT user ID.',
                    ),
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _vehicleName(FleetProvider fleet, String bikeId) {
    for (final v in fleet.vehicles) {
      if (v.id == bikeId) return v.name;
    }
    return bikeId;
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  static String _money(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$text đ';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
