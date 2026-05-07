// @file       more_tab.dart
// @brief      "More" tab — TabBar shell that hosts five sub-sections.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';

import '../../widgets/mqtt_status_badge.dart';
import '../../widgets/vehicle_picker.dart';
import 'more/more_change_password_section.dart';
import 'more/more_employees_section.dart';
import 'more/more_info_section.dart';
import 'more/more_mqtt_section.dart';
import 'more/more_notes_section.dart';

/* Public classes ----------------------------------------------------- */
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('More Options'),
          actions: const [
            MqttStatusBadge(compact: true),
            SizedBox(width: 8),
            VehiclePicker(),
            SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Information'),
              Tab(text: 'Notes'),
              Tab(text: 'Employees'),
              Tab(text: 'Change Password'),
              Tab(text: 'MQTT'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MoreInfoSection(),
            MoreNotesSection(),
            MoreEmployeesSection(),
            MoreChangePasswordSection(),
            MoreMqttSection(),
          ],
        ),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
