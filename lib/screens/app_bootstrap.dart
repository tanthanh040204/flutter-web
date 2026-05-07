// @file       app_bootstrap.dart
// @brief      Screen UI for App Bootstrap.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/feature_config.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/fleet_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/rental_provider.dart';
import '../providers/trip_provider.dart';
import '../services/mqtt_service.dart';
import 'family_root_screen.dart';
import 'login_screen.dart';

/* Public classes ----------------------------------------------------- */
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

/* Private classes ---------------------------------------------------- */
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
    final mqtt = context.read<MqttService>();
    final deviceProvider = context.read<DeviceProvider>();

    void syncAll() {
      final vehicles = List.of(fleet.vehicles);
      final ids = vehicles.map((e) => e.id).toList();
      tripProvider.bindVehicles(ids);
      maintenanceProvider.bindVehicles(vehicles);
      // Ensure all Firebase vehicles are registered in DeviceProvider
      for (final id in ids) {
        deviceProvider.addDevice(id);
      }
    }

    _fleetListener = syncAll;
    fleet.addListener(syncAll);

    // Defer the rest of initialization until after the first frame, to avoid doing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (FeatureConfig.enableFirebase) {
        fleet.bindToFirestore();
      }

      if (FeatureConfig.enableMqtt) {
        _initMqtt(mqtt, fleet, deviceProvider, context.read<RentalProvider>());
      }

      syncAll();
    });

    _inited = true;
  }

  Future<void> _initMqtt(
    MqttService mqtt,
    FleetProvider fleet,
    DeviceProvider deviceProvider,
    RentalProvider rentalProvider,
  ) async {
    try {
      await mqtt.connect();

      // Bind DeviceProvider (MCU direct data: <id>/data, <id>/noti)
      deviceProvider.bindToMqtt(mqtt);

      // Bind FleetProvider backward-compat (vehicleStates stream)
      fleet.bindToMqtt(mqtt);

      // Bind RentalProvider handle rental: start, stop, add tokens, etc.
      rentalProvider.bindToMqtt(mqtt, deviceProvider);

      // Bind RentalProvider to shared Firestore data (parking zones, users).
      rentalProvider.bindToFirebase();

      // subscribeFleetState() subscribes topics of defaultDevices
      await mqtt.subscribeFleetState();
    } catch (e) {
      debugPrint('[AppBootstrap] MQTT init failed: $e');
    }
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

/* End of file -------------------------------------------------------- */
