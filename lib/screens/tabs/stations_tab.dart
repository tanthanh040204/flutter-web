// @file       stations_tab.dart
// @brief      Stations tab — renders parking zones on a map with detail sheet.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parking_zone.dart';
import '../../services/firebase_repo.dart';

/* Constants ---------------------------------------------------------- */
const Color _kMarkerColor = Color(0xFF1557FF);
const Color _kAccentColor = Color(0xFF1557FF);
const String _kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _kUserAgentPkg = 'com.example.flutter_tracking_manager_web';
const LatLng _kFallbackCenter = LatLng(10.849908, 106.771621);

/* Public classes ----------------------------------------------------- */
class StationsTab extends StatelessWidget {
  const StationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ParkingZone>>(
      stream: FirebaseRepo.instance.watchParkingZones(),
      builder: (context, snapshot) {
        final zones = snapshot.data ?? const <ParkingZone>[];
        final center = zones.isNotEmpty
            ? LatLng(zones.first.lat, zones.first.lng)
            : _kFallbackCenter;

        return Scaffold(
          appBar: AppBar(title: const Text('Trạm xe')),
          body: zones.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có trạm nào. Thêm document trong Firestore '
                      'collection "parking_zones" để hiển thị.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 15.2),
                  children: [
                    TileLayer(
                      urlTemplate: _kOsmTileUrl,
                      userAgentPackageName: _kUserAgentPkg,
                    ),
                    MarkerLayer(
                      markers: zones
                          .map(
                            (zone) => Marker(
                              point: LatLng(zone.lat, zone.lng),
                              width: 56,
                              height: 56,
                              child: GestureDetector(
                                onTap: () => _showZoneSheet(context, zone),
                                child: const _ZoneMarker(),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _showZoneSheet(BuildContext context, ParkingZone zone) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                zone.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kAccentColor,
                ),
              ),
              if (zone.address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  zone.address,
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${zone.lat.toStringAsFixed(6)}, ${zone.lng.toStringAsFixed(6)}'
                ' · bán kính ${zone.radiusMeters.toStringAsFixed(0)} m',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openInMaps(zone),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mở Google Maps'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInMaps(ParkingZone zone) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${zone.lat},${zone.lng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/* Private classes ---------------------------------------------------- */
class _ZoneMarker extends StatelessWidget {
  const _ZoneMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: _kMarkerColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.pedal_bike, color: Colors.white, size: 24),
    );
  }
}

/* End of file -------------------------------------------------------- */
