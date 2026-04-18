// @file       location_tab.dart
// @brief      Tab UI for Location.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/vehicle_picker.dart';

import '../../config/app_theme.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';

/* Public classes ----------------------------------------------------- */
class LocationTab extends StatefulWidget {
  const LocationTab({super.key});

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab> {
  bool _showRoute = false;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<FleetProvider>().selectedOrNull;
    if (v == null) {
      return const Scaffold(
        body: Center(child: Text('No device selected in Firebase.')),
      );
    }

    final deviceState = context.watch<DeviceProvider>().deviceById(v.id);
    final routePoints = deviceState?.routePoints ?? const [];
    final routeLatLng = routePoints.map((p) => p.latLng).toList();

    final LatLng loc = v.lastLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: loc, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.route_tracker',
          ),
          if (_showRoute && routeLatLng.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routeLatLng,
                  strokeWidth: 4,
                  color: AppColors.routeLine,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: loc,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, size: 44),
              ),
              if (_showRoute && routeLatLng.isNotEmpty)
                Marker(
                  point: routeLatLng.first,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.flag,
                    size: 28,
                    color: AppColors.startMarker,
                  ),
                ),
              if (_showRoute && routeLatLng.length >= 2)
                Marker(
                  point: routeLatLng.last,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.location_on,
                    size: 28,
                    color: AppColors.endMarker,
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'location-update',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Location on the map will update when Firestore updates lastLocation.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Update'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'location-route-toggle',
            onPressed: () {
              if (routeLatLng.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Not enough points to display route.'),
                  ),
                );
                return;
              }
              setState(() => _showRoute = !_showRoute);
            },
            icon: Icon(_showRoute ? Icons.visibility_off : Icons.alt_route),
            label: Text(_showRoute ? 'Hide route' : 'Show route'),
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
