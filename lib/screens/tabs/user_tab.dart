// @file       user_tab.dart
// @brief      Lists all rental users with profile, balance, status and rental.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../models/rental_user.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/rental_provider.dart';

/* Public classes ----------------------------------------------------- */
class UserTab extends StatelessWidget {
  const UserTab({super.key});

  @override
  Widget build(BuildContext context) {
    final rental = context.watch<RentalProvider>();
    final users = rental.rentalUsers;

    // Cross-reference active rentals (keyed by bikeId) by userId so each
    // user row can show its current session + vehicle, if any.
    final rentalByUser = <String, ActiveRental>{
      for (final r in rental.activeRentals) r.userId: r,
    };
    final activeCount = rentalByUser.length;

    return Scaffold(
      appBar: AppBar(title: Text(context.loc(AppStrings.titleUsers))),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: users.isEmpty
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
                    context.tr('Chưa có người dùng nào', 'No users yet'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Người dùng sẽ xuất hiện ở đây sau khi đăng ký trên ứng dụng di động.',
                      'Users will appear here after they sign up on the mobile app.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _SummaryCard(
                      totalCount: users.length,
                      activeCount: activeCount,
                    );
                  }
                  final user = users[index - 1];
                  return _UserCard(
                    key: ValueKey(user.userId),
                    user: user,
                    activeRental: rentalByUser[user.userId],
                  );
                },
              ),
      ),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalCount, required this.activeCount});

  final int totalCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryStat(
              icon: Icons.people_alt,
              color: Colors.blue,
              label: context.tr('Tổng người dùng', 'Total users'),
              value: '$totalCount',
            ),
            const SizedBox(width: 24),
            _SummaryStat(
              icon: Icons.directions_bike,
              color: Colors.green,
              label: context.tr('Đang thuê xe', 'Currently renting'),
              value: '$activeCount',
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

// All fields (profile, balance, status, contact) come straight from the
// streamed RentalUser, so the card updates live. Stateful only to track the
// in-flight delete.
class _UserCard extends StatefulWidget {
  const _UserCard({super.key, required this.user, this.activeRental});

  final RentalUser user;
  final ActiveRental? activeRental;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _deleting = false;

  Future<void> _confirmDelete(String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Xóa người dùng?', 'Delete user?')),
        content: Text(
          ctx.tr(
            'Người dùng "$displayName" sẽ bị xóa khỏi Firebase (rental_users và hồ sơ users). Hành động này không thể hoàn tác.',
            'User "$displayName" will be deleted from Firebase (rental_users and the users profile). This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final doneText = context.trRead('Đã xóa người dùng', 'User deleted');
    final failText = context.trRead(
      'Xóa người dùng thất bại',
      'Failed to delete user',
    );
    setState(() => _deleting = true);
    try {
      await context.read<RentalProvider>().deleteUser(widget.user.userId);
      messenger.showSnackBar(SnackBar(content: Text(doneText)));
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(failText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final user = widget.user;
    final rental = widget.activeRental;
    final renting = rental != null;
    final name = user.displayName.trim().isNotEmpty
        ? user.displayName
        : user.userId;
    final vehicleName = renting ? _vehicleName(fleet, rental.bikeId) : '--';

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
                  backgroundColor: user.isLocked
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    Icons.person,
                    color: user.isLocked
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        renting
                            ? context.tr(
                                'Đang sử dụng $vehicleName',
                                'Using $vehicleName',
                              )
                            : context.tr(
                                'Không có phiên thuê',
                                'No active rental',
                              ),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                _AccountStatusPill(
                  locked: user.isLocked,
                  active: user.isActive,
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _deleting ? null : () => _confirmDelete(name),
                  tooltip: context.tr('Xóa người dùng', 'Delete user'),
                  icon: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.delete_outline, color: Colors.red.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.qr_code,
              label: context.tr('Mã người dùng', 'User ID'),
              value: user.userId,
            ),
            _InfoRow(
              icon: Icons.email,
              label: 'Email',
              value: user.email ?? '--',
            ),
            _InfoRow(
              icon: Icons.phone,
              label: context.tr('Số điện thoại', 'Phone'),
              value: user.phone ?? '--',
            ),
            _InfoRow(
              icon: Icons.account_balance_wallet,
              label: context.tr('Số dư ví', 'Wallet balance'),
              value: _money(user.tokens),
            ),
            _InfoRow(
              icon: Icons.verified_user,
              label: context.tr('Trạng thái tài khoản', 'Account status'),
              value: user.isLocked
                  ? context.tr('Bị khóa', 'Locked')
                  : (user.isActive
                        ? context.tr('Đang hoạt động', 'Active')
                        : context.tr('Ngừng hoạt động', 'Inactive')),
            ),
            _InfoRow(
              icon: Icons.directions_bike,
              label: context.tr('Phiên thuê hiện tại', 'Current rental'),
              value: renting
                  ? context.tr('Đang thuê', 'Renting')
                  : context.tr('Không có', 'None'),
            ),
            _InfoRow(
              icon: Icons.pedal_bike,
              label: context.tr('Xe đang thuê', 'Vehicle in use'),
              value: renting ? vehicleName : '--',
            ),
            if (renting) ...[
              _InfoRow(
                icon: Icons.schedule,
                label: context.tr('Bắt đầu thuê', 'Rental started at'),
                value: _dateTime(rental.startTime),
              ),
              _InfoRow(
                icon: Icons.timer,
                label: context.tr('Thời lượng hiện tại', 'Current duration'),
                value: _duration(DateTime.now().difference(rental.startTime)),
              ),
              _InfoRow(
                icon: Icons.payments,
                label: context.tr('Đã trừ', 'Charged'),
                value: _money(rental.chargedTokens),
              ),
            ],
          ],
        ),
      ),
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

class _AccountStatusPill extends StatelessWidget {
  const _AccountStatusPill({required this.locked, required this.active});

  final bool locked;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final MaterialColor color;
    final String label;
    if (locked) {
      color = Colors.red;
      label = context.tr('Bị khóa', 'Locked');
    } else if (active) {
      color = Colors.green;
      label = context.tr('Hoạt động', 'Active');
    } else {
      color = Colors.grey;
      label = context.tr('Ngừng', 'Inactive');
    }

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
