// @file       family_root_screen.dart
// @brief      Screen UI for Family Root.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = const [
      ControlTab(),
      StatsTab(),
      LocationTab(),
      HistoryTab(),
      NotificationsTab(),
      UserTab(),
      MoreTab(),
    ];

    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.tune),
            label: lang.tr('Điều khiển', 'Controls'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: lang.tr('Thống kê', 'Statistics'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.location_on),
            label: lang.tr('Trạm xe', 'Stations'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: lang.tr('Lịch sử', 'History'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications),
            label: lang.tr('Thông báo', 'Notifications'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_alt),
            label: lang.tr('Người dùng', 'Users'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.more_horiz),
            label: lang.tr('Mở rộng', 'More'),
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
