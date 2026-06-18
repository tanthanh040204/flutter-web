// @file       more_info_section.dart
// @brief      Information sub-tab — current employee, vehicle count, logout.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/fleet_provider.dart';

/* Public classes ----------------------------------------------------- */
class MoreInfoSection extends StatelessWidget {
  const MoreInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Logged-in Employee Code'),
          trailing: Text(auth.employeeCode ?? '---'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.directions_car_outlined),
          title: const Text('Vehicles managed'),
          trailing: Text('${fleet.vehicles.length}'),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usage Tips',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Noti tab for notifications from devices.'),
                SizedBox(height: 4),
                Text('• Tab Notes for creating and managing notes.'),
                SizedBox(height: 4),
                Text('• Tab change password to update your login password.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

/* End of file -------------------------------------------------------- */
