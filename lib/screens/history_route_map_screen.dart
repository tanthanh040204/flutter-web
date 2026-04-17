// @file       history_route_map_screen.dart
// @brief      Screen UI for History Route Map.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/history_route.dart';

/* Public classes ----------------------------------------------------- */
class HistoryRouteMapScreen extends StatelessWidget {
  final HistoryRouteRecord route;

  const HistoryRouteMapScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final center = route.points.isNotEmpty
        ? route.points.first
        : const LatLng(21.0287, 105.8522);

    return Scaffold(
      appBar: AppBar(title: Text(route.buttonLabel)),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.route_tracker',
          ),
          if (route.points.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route.points,
                  strokeWidth: 5,
                  color: Colors.blue,
                ),
              ],
            ),
          if (route.points.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: route.points.first,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                Marker(
                  point: route.points.last,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.stop, color: Colors.red, size: 28),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */