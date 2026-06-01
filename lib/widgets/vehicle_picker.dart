// @file       vehicle_picker.dart
// @brief      Widget for Vehicle Picker with rental on/off status.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/device_state.dart';
import '../models/vehicle.dart';
import '../providers/device_provider.dart';
import '../providers/fleet_provider.dart';

/* Public classes ----------------------------------------------------- */
class VehiclePicker extends StatelessWidget {
  const VehiclePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final devices = context.watch<DeviceProvider>();
    if (fleet.vehicles.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 42,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDEAF4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: fleet.selectedIndex,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          selectedItemBuilder: (context) {
            return List.generate(fleet.vehicles.length, (i) {
              final vehicle = fleet.vehicles[i];
              final isOn = _isVehicleInUse(vehicle, devices);
              return _VehicleDropdownItem(
                name: vehicle.name,
                isOn: isOn,
                compact: true,
              );
            });
          },
          items: List.generate(fleet.vehicles.length, (i) {
            final vehicle = fleet.vehicles[i];
            final isOn = _isVehicleInUse(vehicle, devices);
            return DropdownMenuItem<int>(
              value: i,
              child: _VehicleDropdownItem(name: vehicle.name, isOn: isOn),
            );
          }),
          onChanged: (i) {
            if (i != null) context.read<FleetProvider>().selectVehicle(i);
          },
        ),
      ),
    );
  }
}

/* Private helpers ---------------------------------------------------- */
bool _isVehicleInUse(
  Vehicle vehicle,
  DeviceProvider devices,
) {
  final state = devices.deviceById(vehicle.id);

  // ON/OFF must follow the physical lock state only.
  // Opened/unlocked => ON. Locked or pause/locked => OFF.
  if (state != null) {
    return state.lockState == DeviceLockState.active;
  }

  return !vehicle.isLocked;
}

class _VehicleDropdownItem extends StatelessWidget {
  const _VehicleDropdownItem({
    required this.name,
    required this.isOn,
    this.compact = false,
  });

  final String name;
  final bool isOn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 210 : 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.electric_scooter_rounded,
              color: AppColors.primaryDark,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 14 : 15,
                color: AppColors.dark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(isOn: isOn),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOn});

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    final color = isOn ? AppColors.success : AppColors.danger;
    final label = isOn ? 'ON' : 'OFF';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
