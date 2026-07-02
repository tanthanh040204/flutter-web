// @file       location_tab.dart
// @brief      Tab UI for Location — single-vehicle focus and track-all mode.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../config/app_theme.dart';
import '../../models/device_state.dart';
import '../../models/parking_zone.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_repo.dart';
import '../../widgets/vehicle_picker.dart';

/* Constants ---------------------------------------------------------- */
// Parking-zone overlay styling (matches the standalone stations map).
const Color _kZoneFillColor = Color(0x331557FF);
const Color _kZoneBorderColor = Color(0xFF1557FF);
const double _kZoneBorderWidth = 2.0;

/* Public classes ----------------------------------------------------- */
class LocationTab extends StatefulWidget {
  const LocationTab({super.key});

  @override
  State<LocationTab> createState() => _LocationTabState();
}

class _LocationTabState extends State<LocationTab> {
  // ---- private fields ------------------------------------------------
  bool _showRoute = false;
  bool _trackAll = false;
  final MapController _mapController = MapController();

  // Used to detect VehiclePicker selection changes in track-all mode
  String? _lastSelectedId;

  // Parking zones overlaid on the same map (rarely change → simple sub).
  List<ParkingZone> _zones = const <ParkingZone>[];
  StreamSubscription<List<ParkingZone>>? _zonesSub;

  @override
  void initState() {
    super.initState();
    _zonesSub = FirebaseRepo.instance.watchParkingZones().listen((zones) {
      if (!mounted) return;
      setState(() => _zones = zones);
    });
  }

  // ---- private methods -----------------------------------------------
  Widget _buildLegend(List<dynamic> vehicles, DeviceProvider dp) {
    return Card(
      // ignore: deprecated_member_use
      color: Colors.white.withOpacity(0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final vehicle in vehicles)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: () {
                          final ds = dp.deviceById(vehicle.id as String);
                          return ds != null ? _hexColor(ds.color) : Colors.blue;
                        }(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.name as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    return Color(int.parse(h, radix: 16) | 0xFF000000);
  }

  Widget _buildBikeMarker(BuildContext context, DeviceState? ds, Color? color) {
    if (ds?.helpRequested ?? false) {
      return const Icon(Icons.warning, size: 44, color: Colors.red);
    }
    if ((ds?.deviceErrors.isNotEmpty ?? false)) {
      return GestureDetector(
        onTap: () => _showDeviceErrorDialog(context, ds!),
        child: const Icon(
          Icons.warning_amber_rounded,
          size: 44,
          color: Color(0xFFF9A825),
        ),
      );
    }
    return color != null
        ? Icon(Icons.location_on, size: 44, color: color)
        : const Icon(Icons.location_on, size: 44);
  }

  void _showDeviceErrorDialog(BuildContext context, DeviceState ds) {
    final lang = context.read<LanguageProvider>();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          lang.tr('Lỗi thiết bị ${ds.id}', 'Device errors - ${ds.id}'),
        ),
        content: Text(deviceErrorNames(context, ds.deviceErrors)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('Đóng', 'Close')),
          ),
        ],
      ),
    );
  }

  void _fitAll(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final deviceProvider = context.watch<DeviceProvider>();

    final v = fleet.selectedOrNull;
    if (v == null) {
      return const Scaffold(
        body: Center(child: Text('No device selected in Firebase.')),
      );
    }

    // In track-all mode: VehiclePicker moves the camera to the picked vehicle
    // without switching out of track-all mode.
    if (_trackAll && _lastSelectedId != null && v.id != _lastSelectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(v.lastLocation, 15);
      });
    }
    _lastSelectedId = v.id;

    // Build markers and polylines depending on mode
    final markers = <Marker>[];
    final polylines = <Polyline>[];

    if (_trackAll) {
      for (final vehicle in fleet.vehicles) {
        final ds = deviceProvider.deviceById(vehicle.id);
        final color = ds != null ? _hexColor(ds.color) : Colors.blue;
        final loc = vehicle.lastLocation;

        markers.add(
          Marker(
            point: loc,
            width: 50,
            height: 50,
            child: _buildBikeMarker(context, ds, color),
          ),
        );

        if (_showRoute && ds != null) {
          final pts = ds.routePoints.map((p) => p.latLng).toList();
          if (pts.length >= 2) {
            polylines.add(Polyline(points: pts, strokeWidth: 4, color: color));
            markers.add(
              Marker(
                point: pts.first,
                width: 44,
                height: 44,
                child: Icon(Icons.flag, size: 28, color: color),
              ),
            );
            markers.add(
              Marker(
                point: pts.last,
                width: 44,
                height: 44,
                // ignore: deprecated_member_use
                child: Icon(
                  Icons.location_on,
                  size: 28,
                  color: color.withOpacity(0.7),
                ),
              ),
            );
          }
        }
      }
    } else {
      final ds = deviceProvider.deviceById(v.id);
      final routeLatLng = ds?.routePoints.map((p) => p.latLng).toList() ?? [];
      final loc = v.lastLocation;

      markers.add(
        Marker(
          point: loc,
          width: 50,
          height: 50,
          child: _buildBikeMarker(context, ds, null),
        ),
      );

      if (_showRoute && routeLatLng.isNotEmpty) {
        markers.add(
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
        );
        if (routeLatLng.length >= 2) {
          polylines.add(
            Polyline(
              points: routeLatLng,
              strokeWidth: 4,
              color: AppColors.routeLine,
            ),
          );
          markers.add(
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
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc(AppStrings.titleLocation)),
        actions: [
          FilterChip(
            label: Text(context.loc(AppStrings.trackAll)),
            selected: _trackAll,
            onSelected: (val) {
              setState(() => _trackAll = val);
              if (val) {
                final allPoints = fleet.vehicles
                    .map((ve) => ve.lastLocation)
                    .toList();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _fitAll(allPoints),
                );
              } else {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _mapController.move(v.lastLocation, 15),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          const VehiclePicker(),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: v.lastLocation, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.route_tracker',
              ),
              if (_zones.isNotEmpty)
                CircleLayer(
                  circles: _zones
                      .map(
                        (zone) => CircleMarker(
                          point: LatLng(zone.lat, zone.lng),
                          radius: zone.radiusMeters,
                          useRadiusInMeter: true,
                          color: _kZoneFillColor,
                          borderColor: _kZoneBorderColor,
                          borderStrokeWidth: _kZoneBorderWidth,
                        ),
                      )
                      .toList(),
                ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (_zones.isNotEmpty)
                MarkerLayer(
                  markers: _zones
                      .map(
                        (zone) => Marker(
                          point: LatLng(zone.lat, zone.lng),
                          width: 40,
                          height: 40,
                          child: Tooltip(
                            message: zone.name,
                            child: const Icon(
                              Icons.local_parking,
                              color: _kZoneBorderColor,
                              size: 28,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (_trackAll)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _buildLegend(fleet.vehicles, deviceProvider),
            ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_trackAll)
            FloatingActionButton.extended(
              heroTag: 'location-fit-all',
              onPressed: () {
                final allPoints = fleet.vehicles
                    .map((ve) => ve.lastLocation)
                    .toList();
                _fitAll(allPoints);
              },
              icon: const Icon(Icons.fit_screen),
              label: Text(context.loc(AppStrings.fitMap)),
            )
          else
            FloatingActionButton.extended(
              heroTag: 'location-update',
              onPressed: () {
                // Center on the freshest live GPS straight from device data
                // (MQTT), falling back to the last known location.
                final live = deviceProvider.deviceById(v.id)?.latest;
                final hasLive = live != null && live.hasGps;
                final target = hasLive
                    ? LatLng(live.lat!, live.lng!)
                    : v.lastLocation;
                _mapController.move(target, _mapController.camera.zoom);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      hasLive
                          ? 'Centered on the latest live position.'
                          : 'No fresh GPS yet — showing last known position.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.loc(AppStrings.locationUpdate)),
            ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'location-route-toggle',
            onPressed: () {
              if (!_trackAll) {
                final ds = deviceProvider.deviceById(v.id);
                if ((ds?.routePoints.length ?? 0) < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not enough points to display route.'),
                    ),
                  );
                  return;
                }
              }
              setState(() => _showRoute = !_showRoute);
            },
            icon: Icon(_showRoute ? Icons.visibility_off : Icons.alt_route),
            label: Text(
              _showRoute
                  ? context.loc(AppStrings.hideRoute)
                  : context.loc(AppStrings.showRoute),
            ),
          ),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
