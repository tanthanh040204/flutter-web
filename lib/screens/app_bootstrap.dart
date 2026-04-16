import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/feature_config.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/fleet_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/trip_provider.dart';
import '../services/mqtt_service.dart';
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
    final mqtt = context.read<MqttService>();
    final deviceProvider = context.read<DeviceProvider>();

    void syncAll() {
      final vehicles = List.of(fleet.vehicles);
      final ids = vehicles.map((e) => e.id).toList();
      tripProvider.bindVehicles(ids);
      maintenanceProvider.bindVehicles(vehicles);
    }

    _fleetListener = syncAll;
    fleet.addListener(syncAll);

    // Defer tất cả init sang sau frame đầu để tránh
    // "setState() called during build" khi Firestore listener
    // trả data ngay lập tức (cached).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (FeatureConfig.enableFirebase) {
        fleet.bindToFirestore();
      }

      if (FeatureConfig.enableMqtt) {
        _initMqtt(mqtt, fleet, deviceProvider);
      }

      syncAll();
    });

    _inited = true;
  }

  Future<void> _initMqtt(
    MqttService mqtt,
    FleetProvider fleet,
    DeviceProvider deviceProvider,
  ) async {
    try {
      await mqtt.connect();

      // Bind DeviceProvider (MCU direct data: <id>/data, <id>/noti)
      deviceProvider.bindToMqtt(mqtt);

      // Bind FleetProvider backward-compat (vehicleStates stream)
      fleet.bindToMqtt(mqtt);

      // subscribeFleetState() nay subscribe topics của defaultDevices
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
