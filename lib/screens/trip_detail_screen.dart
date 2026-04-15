import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip.dart';

class TripDetailScreen extends StatelessWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final points = trip.points.map((p) => p.latLng).toList();
    final center = points.isEmpty ? const LatLng(0, 0) : points[points.length ~/ 2];

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hành trình')),
      body: Column(
        children: [
          _Summary(trip: trip),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.route_tracker',
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: points, strokeWidth: 4),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (points.isNotEmpty)
                      Marker(
                        point: points.first,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.flag, size: 34),
                      ),
                    if (points.isNotEmpty)
                      Marker(
                        point: points.last,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_on, size: 34),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _SpeedChips(trip: trip),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Trip trip;
  const _Summary({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_fmtDate(trip.startTime)}  •  ${_fmtTime(trip.startTime)} → ${_fmtTime(trip.endTime)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Quãng đường: ${trip.distanceKm.toStringAsFixed(2)} km'),
          Text('Tốc độ TB: ${trip.avgSpeedKmh.toStringAsFixed(1)} km/h  •  Tối đa: ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h'),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  static String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _SpeedChips extends StatelessWidget {
  final Trip trip;
  const _SpeedChips({required this.trip});

  @override
  Widget build(BuildContext context) {
    final pts = trip.points;
    final tail = pts.length <= 8 ? pts : pts.sublist(pts.length - 8);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tốc độ (mẫu điểm cuối)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tail.map((p) {
              final t = '${p.time.hour.toString().padLeft(2, '0')}:${p.time.minute.toString().padLeft(2, '0')}';
              return Chip(label: Text('$t • ${p.speedKmh.toStringAsFixed(0)} km/h'));
            }).toList(),
          ),
        ],
      ),
    );
  }
}
