import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/fleet_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/trip_provider.dart';
import 'family_root_screen.dart';
import 'login_screen.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _inited = false;
  VoidCallback? _fleetListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;

    final fleet = context.read<FleetProvider>();
    final tripProvider = context.read<TripProvider>();
    final maintenanceProvider = context.read<MaintenanceProvider>();

    void syncAll() {
      final vehicles = List.of(fleet.vehicles);
      final ids = vehicles.map((e) => e.id).toList();

      tripProvider.bindVehicles(ids);
      maintenanceProvider.bindVehicles(vehicles);
    }

    fleet.bindToFirestore();

    _fleetListener = syncAll;
    fleet.addListener(syncAll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncAll();
    });

    _inited = true;
  }

  @override
  void dispose() {
    final listener = _fleetListener;
    if (listener != null) {
      try {
        context.read<FleetProvider>().removeListener(listener);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const FamilyRootScreen() : const LoginScreen();
  }
}
