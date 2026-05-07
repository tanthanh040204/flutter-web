// @file       family_root_screen.dart
// @brief      Screen UI for Family Root.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';

import 'tabs/control_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/location_tab.dart';
import 'tabs/stations_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/notifications_tab.dart';
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
      StationsTab(),
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
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Controls'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Location'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: 'Stations',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
