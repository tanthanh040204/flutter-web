import 'package:flutter/material.dart';

import 'tabs/control_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/location_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/more_tab.dart';

class FamilyRootScreen extends StatefulWidget {
  const FamilyRootScreen({super.key});

  @override
  State<FamilyRootScreen> createState() => _FamilyRootScreenState();
}

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
      MoreTab(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Điều khiển'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Thông số'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Địa điểm'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Khác'),
        ],
      ),
    );
  }
}
