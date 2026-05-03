// @file       history_route_map_screen.dart
// @brief      Screen UI for live History Route Map.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/history_route.dart';
import '../services/firebase_repo.dart';
import '../providers/language_provider.dart';

/* Public classes ----------------------------------------------------- */
class HistoryRouteMapScreen extends StatelessWidget {
  final HistoryRouteRecord route;

  const HistoryRouteMapScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HistoryRouteRecord?>(
      initialData: route,
      stream: FirebaseRepo.instance.watchHistoryRoute(route.vehicleId, route.id),
      builder: (context, snap) {
        final current = snap.data ?? route;
        return Scaffold(
          appBar: AppBar(title: Text(current.buttonLabel)),
          body: _HistoryRouteMap(route: current),
        );
      },
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _HistoryRouteMap extends StatelessWidget {
  final HistoryRouteRecord route;

  const _HistoryRouteMap({required this.route});

  static const LatLng _fallbackCenter = LatLng(10.7769, 106.7009);

  @override
  Widget build(BuildContext context) {
    final points = route.points;
    final center = points.isNotEmpty ? points.last : _fallbackCenter;

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey('${route.id}_${points.length}_${center.latitude}_${center.longitude}'),
          options: MapOptions(initialCenter: center, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.route_tracker',
            ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 5,
                    color: Colors.blue,
                  ),
                ],
              ),
            if (points.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: points.first,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                  Marker(
                    point: points.last,
                    width: 44,
                    height: 44,
                    child: Icon(
                      route.isClosed ? Icons.stop : Icons.location_pin,
                      color: route.isClosed ? Colors.red : Colors.blue,
                      size: 32,
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  offset: Offset(0, 4),
                  color: Colors.black26,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    route.isClosed ? Icons.check_circle : Icons.sync,
                    color: route.isClosed ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      points.length >= 2
                          ? context.tr('Đã ghi ${points.length} điểm lộ trình • ${route.distanceKm.toStringAsFixed(2)} km', 'Recorded ${points.length} route points • ${route.distanceKm.toStringAsFixed(2)} km')
                          : context.tr('Đang chờ thêm dữ liệu GPS hợp lệ để vẽ lộ trình', 'Waiting for more valid GPS data to draw the route'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* End of file -------------------------------------------------------- */
