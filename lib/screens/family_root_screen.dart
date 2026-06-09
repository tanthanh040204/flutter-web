// @file       family_root_screen.dart
// @brief      Main web dashboard shell.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_string.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/fleet_provider.dart';
import '../providers/language_provider.dart';

import 'tabs/control_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/location_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/user_tab.dart';
import 'tabs/more_tab.dart';

/* Public classes ----------------------------------------------------- */
class FamilyRootScreen extends StatefulWidget {
  const FamilyRootScreen({super.key});

  @override
  State<FamilyRootScreen> createState() => _FamilyRootScreenState();
}

/* Private classes ---------------------------------------------------- */
class _FamilyRootScreenState extends State<FamilyRootScreen> {
  int index = 0;

  static const _pages = [
    ControlTab(),
    StatsTab(),
    LocationTab(),
    HistoryTab(),
    NotificationsTab(),
    UserTab(),
    MoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final items = [
      _NavItemData(
        icon: Icons.tune_rounded,
        selectedIcon: Icons.dashboard_customize_rounded,
        label: lang.loc(AppStrings.navControl),
      ),
      _NavItemData(
        icon: Icons.insights_rounded,
        selectedIcon: Icons.bar_chart_rounded,
        label: lang.loc(AppStrings.navStats),
      ),
      _NavItemData(
        icon: Icons.location_on_outlined,
        selectedIcon: Icons.location_on_rounded,
        label: lang.loc(AppStrings.navStations),
      ),
      _NavItemData(
        icon: Icons.route_outlined,
        selectedIcon: Icons.route_rounded,
        label: lang.loc(AppStrings.navHistory),
      ),
      _NavItemData(
        icon: Icons.notifications_none_rounded,
        selectedIcon: Icons.notifications_active_rounded,
        label: lang.loc(AppStrings.navNotifications),
      ),
      _NavItemData(
        icon: Icons.people_alt_outlined,
        selectedIcon: Icons.people_alt_rounded,
        label: lang.loc(AppStrings.navUsers),
      ),
      _NavItemData(
        icon: Icons.grid_view_rounded,
        selectedIcon: Icons.widgets_rounded,
        label: lang.loc(AppStrings.navMore),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        if (desktop) {
          return Scaffold(
            body: _DashboardBackground(
              child: Row(
                children: [
                  _DashboardSideBar(
                    index: index,
                    items: items,
                    onChanged: (i) => setState(() => index = i),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: _pages[index],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: _DashboardBackground(child: _pages[index]),
          bottomNavigationBar: _GlassBottomNav(
            index: index,
            items: items,
            onChanged: (i) => setState(() => index = i),
          ),
        );
      },
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FCFF), Color(0xFFEAF6FF), Color(0xFFF8FAFC)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _DashboardPattern()),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _DashboardPattern extends StatelessWidget {
  const _DashboardPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashboardPatternPainter());
  }
}

class _DashboardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = AppColors.primary.withOpacity(0.045);
    final cyan = Paint()..color = AppColors.cyan.withOpacity(0.07);
    final green = Paint()..color = AppColors.accent.withOpacity(0.055);

    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.08), 160, cyan);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.92), 210, blue);
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.88),
      130,
      green,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardSideBar extends StatelessWidget {
  const _DashboardSideBar({
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<_NavItemData> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fleet = context.watch<FleetProvider>();
    final lang = context.watch<LanguageProvider>();

    return Container(
      width: 278,
      margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B5E), Color(0xFF075985), Color(0xFF0B78B6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF075985).withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandBlock(),
          const SizedBox(height: 18),
          _OperatorCard(
            employeeCode: auth.employeeCode ?? '--',
            vehicleCount: fleet.vehicles.length,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, i) {
                return _SideNavTile(
                  data: items[i],
                  selected: index == i,
                  onTap: () => onChanged(i),
                );
              },
            ),
          ),
          _ShiftReminder(
            title: lang.tr('Nhắc ca trực', 'Shift reminder'),
            text: lang.tr(
              'Ghi chú dữ liệu từng xe trước khi tan ca.',
              'Record each vehicle\'s data before ending your shift.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.pedal_bike, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.brandShort,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                AppStrings.brandManager,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFD9F5FF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.employeeCode, required this.vehicleCount});

  final String employeeCode;
  final int vehicleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Icon(Icons.badge_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$vehicleCount xe đang quản lý',
                  style: const TextStyle(
                    color: Color(0xFFCDEEFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? data.selectedIcon : data.icon,
                color: selected ? AppColors.primaryDark : Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primaryDark : Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftReminder extends StatelessWidget {
  const _ShiftReminder({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFDE68A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFEAF8FF),
                    height: 1.3,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<_NavItemData> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE1EEF7)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: onChanged,
            type: BottomNavigationBarType.fixed,
            items: [
              for (final item in items)
                BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
