// @file       vehicle_picker.dart
// @brief      Widget for Vehicle Picker.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fleet_provider.dart';

/* Public classes ----------------------------------------------------- */
class VehiclePicker extends StatelessWidget {
  const VehiclePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    if (fleet.vehicles.isEmpty) return const SizedBox.shrink();

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: fleet.selectedIndex,
        items: List.generate(fleet.vehicles.length, (i) {
          final v = fleet.vehicles[i];
          return DropdownMenuItem(value: i, child: Text(v.name));
        }),
        onChanged: (i) {
          if (i != null) context.read<FleetProvider>().selectVehicle(i);
        },
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */