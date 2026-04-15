import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'models/bluetooth_device_info.dart';
import 'providers/auth_provider.dart';
import 'providers/bluetooth_provider.dart';
import 'providers/fleet_provider.dart';
import 'providers/fota_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/route_provider.dart';
import 'providers/streaming_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/app_bootstrap.dart';
import 'services/mqtt_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e, st) {
    debugPrint('Firebase init skipped: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(const RouteTrackerApp());
}

class RouteTrackerApp extends StatelessWidget {
  const RouteTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MqttService>(
          create: (_) => MqttService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => StreamingProvider()),
        ChangeNotifierProvider(create: (_) => FotaProvider()),
        ChangeNotifierProvider(create: (_) => FleetProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ],
      child: Builder(
        builder: (context) {
          final bluetoothProvider = Provider.of<BluetoothProvider>(context);
          final streamingProvider = Provider.of<StreamingProvider>(
            context,
            listen: false,
          );
          final fotaProvider = Provider.of<FotaProvider>(
            context,
            listen: false,
          );

          bluetoothProvider.addListener(() {
            if (bluetoothProvider.connectionState ==
                AppBluetoothConnectionState.disconnected) {
              streamingProvider.clearAll();
              fotaProvider.clearAll();
            }
          });

          return MaterialApp(
            title: 'Route Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const AppBootstrap(),
          );
        },
      ),
    );
  }
}
