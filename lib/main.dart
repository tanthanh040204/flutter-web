// @file       main.dart
// @brief      App entry point.

/* Imports ------------------------------------------------------------ */
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/fleet_provider.dart';
import 'providers/language_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/rental_provider.dart';
import 'providers/stations_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/landing_shell.dart';
import 'services/mqtt_service.dart';

/* Entry point -------------------------------------------------------- */
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

/* Public classes ----------------------------------------------------- */
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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FleetProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
        ChangeNotifierProvider(create: (_) => RentalProvider()),
        ChangeNotifierProvider(create: (_) => StationsProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, language, _) {
          return MaterialApp(
            title: language.tr('Theo dõi lộ trình', 'Route Tracker'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const LandingShell(),
          );
        },
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */