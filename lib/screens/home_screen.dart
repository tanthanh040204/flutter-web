// @file       home_screen.dart
// @brief      Screen UI for Home.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';
import '../providers/streaming_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/toolbar_buttons.dart';
import '../widgets/info_overlay.dart';
import 'bluetooth_page.dart';
import 'fota_page.dart';
import 'package:latlong2/latlong.dart';

/* Public classes ----------------------------------------------------- */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/* Private classes ---------------------------------------------------- */
class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<MapWidgetState> _mapKey = GlobalKey();
  StreamSubscription? _realtimeSubscription;
  late final VoidCallback _routeListener;
  int _lastRouteLength = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
    });
    // Listen for route changes to auto-fit map
    final routeProvider = context.read<RouteProvider>();
    _lastRouteLength = routeProvider.points.length;
    _routeListener = () {
      final newLength = routeProvider.points.length;
      if (newLength > 1 && newLength != _lastRouteLength) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapKey.currentState?.fitToRoute();
        });
      }
      _lastRouteLength = newLength;
    };
    routeProvider.addListener(_routeListener);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    context.read<RouteProvider>().removeListener(_routeListener);
    super.dispose();
  }

  void _setupListeners() {
    final btProvider = context.read<BluetoothProvider>();
    final routeProvider = context.read<RouteProvider>();
    final streamingProvider = context.read<StreamingProvider>();

    // Realtime mode: add points to route and streaming
    _realtimeSubscription = btProvider.dataStream.listen((point) {
      // Always add to route if realtimeMode is on
      if (routeProvider.realtimeMode) {
        routeProvider.addPoint(point);
      }

      // Always update current position when connected (for live tracking)
      // Streaming mode controls whether to record history
      streamingProvider.updateCurrentPoint(point);

      // Auto-start streaming when first point received
      if (!streamingProvider.isStreaming && btProvider.isConnected) {
        streamingProvider.startStreaming();
      }

      // Auto-fit map to route whenever streaming mode uploads to map
      if (streamingProvider.isStreaming) {
        final points = streamingProvider.streamedPoints;
        // If route on map is not the same as streaming points, update and fit
        if (points.isNotEmpty &&
            (routeProvider.points.length != points.length ||
                routeProvider.points.isEmpty)) {
          routeProvider.setPoints(points);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapKey.currentState?.fitToRoute();
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Tracker'),
        actions: [
          // Bluetooth button
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'Bluetooth',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BluetoothPage(
                    onUploadToMap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _mapKey.currentState?.fitToRoute();
                      });
                    },
                  ),
                ),
              );
            },
          ),
          // FOTA Update button
          Consumer<BluetoothProvider>(
            builder: (context, btProvider, _) {
              final isConnected = btProvider.isConnected;
              return IconButton(
                icon: Icon(
                  Icons.system_update,
                  color: isConnected ? null : AppColors.gray400,
                ),
                tooltip: isConnected ? 'FOTA Update' : 'Connect to BLE first',
                onPressed: isConnected
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FotaPage()),
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please connect to Bluetooth device first'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      },
              );
            },
          ),
          // Upload button
          const UploadToolbarButton(),
          // Controls button
          ControlsToolbarButton(
            onFitRoute: () => _mapKey.currentState?.fitToRoute(),
            onCenterUser: () {
              final streamingProvider = context.read<StreamingProvider>();
              if (streamingProvider.currentPoint != null) {
                _mapKey.currentState?.centerOn(
                  LatLng(
                    streamingProvider.currentPoint!.latitude,
                    streamingProvider.currentPoint!.longitude,
                  ),
                );
              }
            },
          ),
          // Zoom to fit
          Consumer<RouteProvider>(
            builder: (context, routeProvider, child) {
              return IconButton(
                icon: const Icon(Icons.zoom_out_map),
                tooltip: 'Fit entire route',
                onPressed: routeProvider.hasRoute
                    ? () => _mapKey.currentState?.fitToRoute()
                    : null,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map (full screen)
          MapWidget(key: _mapKey),
          // Info overlay
          const Positioned.fill(child: InfoOverlay()),
          // FAB for quick actions
          Positioned(right: 16, bottom: 100, child: _buildQuickActionsFAB()),
        ],
      ),
    );
  }

  Widget _buildQuickActionsFAB() {
    return Consumer2<StreamingProvider, BluetoothProvider>(
      builder: (context, streamingProvider, btProvider, child) {
        final isConnected = btProvider.isConnected;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle streaming - enable only when Bluetooth is connected
            FloatingActionButton.small(
              heroTag: 'streaming',
              onPressed: isConnected
                  ? () {
                      if (streamingProvider.isStreaming) {
                        streamingProvider.stopStreaming();
                      } else {
                        streamingProvider.startStreaming();
                      }
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng kết nối Bluetooth MCU trước'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
              backgroundColor: !isConnected
                  ? AppColors.gray500
                  : streamingProvider.isStreaming
                  ? AppColors.danger
                  : AppColors.primary,
              child: Icon(
                streamingProvider.isStreaming ? Icons.stop : Icons.play_arrow,
              ),
            ),
            const SizedBox(height: 8),

            // Center on current position
            FloatingActionButton.small(
              heroTag: 'center',
              onPressed: streamingProvider.currentPoint != null
                  ? () {
                      _mapKey.currentState?.centerOn(
                        streamingProvider.currentPoint!.latLng,
                      );
                    }
                  : null,
              backgroundColor: streamingProvider.currentPoint != null
                  ? AppColors.white
                  : AppColors.gray300,
              foregroundColor: streamingProvider.currentPoint != null
                  ? AppColors.primary
                  : AppColors.gray500,
              child: const Icon(Icons.my_location),
            ),
          ],
        );
      },
    );
  }
}

/* End of file -------------------------------------------------------- */
