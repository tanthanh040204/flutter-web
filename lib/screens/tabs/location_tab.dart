// @file       location_tab.dart
// @brief      Tab UI for Location and bike stations.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_theme.dart';
import '../../models/station.dart';
import '../../models/vehicle.dart';
import '../../providers/device_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/stations_provider.dart';
import '../../widgets/vehicle_picker.dart';

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
    final fleet = context.watch<FleetProvider>();
    final stationsProvider = context.watch<StationsProvider>();
    final deviceProvider = context.watch<DeviceProvider>();

    final selectedVehicle = fleet.selectedOrNull;
    final stations = stationsProvider.stations;
    final userPoint = stationsProvider.currentUserLocation;

    final deviceState = selectedVehicle == null
        ? null
        : deviceProvider.deviceById(selectedVehicle.id);
    final routePoints = deviceState?.routePoints ?? const [];
    final routeLatLng = routePoints.map((p) => p.latLng).toList();

    final center =
        selectedVehicle?.lastLocation ??
        (stations.isNotEmpty ? stations.first.point : userPoint);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Trạm xe', 'Stations')),
        actions: [
          if (fleet.hasVehicles) const VehiclePicker(),
          const SizedBox(width: 8),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 15.2),
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
              ...stations.map(
                (station) => Marker(
                  point: station.point,
                  width: 68,
                  height: 68,
                  child: GestureDetector(
                    onTap: () =>
                        _showStationSheet(context, station, fleet.vehicles),
                    child: _StationMarker(count: station.bikeCount),
                  ),
                ),
              ),
              if (selectedVehicle != null)
                Marker(
                  point: selectedVehicle.lastLocation,
                  width: 54,
                  height: 54,
                  child: Tooltip(
                    message:
                        '${selectedVehicle.name} - ${selectedVehicle.batteryPercent}% ${context.tr('pin', 'battery')}',
                    child: const Icon(Icons.location_on, size: 44),
                  ),
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
            onPressed: () async {
              await context.read<StationsProvider>().refreshUserLocation();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('Đã cập nhật vị trí và danh sách trạm xe.', 'Updated location and station list.')),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Cập nhật', 'Update')),
          ),
          const SizedBox(width: 12),
          if (selectedVehicle != null)
            FloatingActionButton.extended(
              heroTag: 'location-route-toggle',
              onPressed: () {
                if (routeLatLng.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Chưa đủ điểm GPS để hiển thị lộ trình.', 'Not enough GPS points to show route.')),
                    ),
                  );
                  return;
                }
                setState(() => _showRoute = !_showRoute);
              },
              icon: Icon(_showRoute ? Icons.visibility_off : Icons.alt_route),
              label: Text(_showRoute ? context.tr('Ẩn lộ trình', 'Hide route') : context.tr('Hiện lộ trình', 'Show route')),
            ),
        ],
      ),
    );
  }

  Future<void> _showStationSheet(
    BuildContext context,
    BikeStation station,
    List<Vehicle> liveVehicles,
  ) async {
    final vehicles = _resolveStationVehicles(station, liveVehicles);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.35,
        maxChildSize: 0.86,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                station.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                station.address,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StationStat(
                      label: context.tr('Xe hiện có', 'Available bikes'),
                      value: station.bikeCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StationStat(
                      label: context.tr('Chỗ trống', 'Empty slots'),
                      value: station.availableSlots.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: station.googleMapUrl),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Đã copy link Google Maps của trạm.', 'Copied the station Google Maps link.')),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: Text(context.tr('Copy link Google Maps', 'Copy Google Maps link')),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Danh sách xe tại trạm', 'Bikes at this station'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    context.tr('${vehicles.length} xe', '${vehicles.length} bikes'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(context.tr('Trạm này chưa có xe.', 'This station has no bikes.'))),
                )
              else
                ...vehicles.map((bike) => _StationVehicleCard(vehicle: bike)),
              const SizedBox(height: 6),
              Text(
                context.tr('Lưu ý: nếu mã xe tại trạm trùng với xe trong Firebase/MQTT, phần trăm pin sẽ tự lấy theo dữ liệu mới nhất của xe đó.', 'Note: if a station bike code matches a vehicle in Firebase/MQTT, its battery percentage is taken from the latest vehicle data.'),
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<StationVehicleInfo> _resolveStationVehicles(
    BikeStation station,
    List<Vehicle> liveVehicles,
  ) {
    return station.vehicles.map((bike) {
      final code = bike.code.toLowerCase().trim();
      Vehicle? live;
      for (final v in liveVehicles) {
        if (v.id.toLowerCase() == code || v.name.toLowerCase() == code) {
          live = v;
          break;
        }
      }

      if (live == null) return bike;

      return bike.copyWith(
        batteryPercent: live.batteryPercent,
        status: live.isRunning
            ? 'Đang sử dụng'
            : live.isLocked
            ? 'Sẵn sàng'
            : 'Đã mở khóa',
      );
    }).toList();
  }
}

class _StationMarker extends StatelessWidget {
  final int count;

  const _StationMarker({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Color(0xFF1557FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.pedal_bike, color: Colors.white, size: 25),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StationStat extends StatelessWidget {
  final String label;
  final String value;

  const _StationStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _StationVehicleCard extends StatelessWidget {
  final StationVehicleInfo vehicle;

  const _StationVehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (vehicle.status) {
      'Đang sử dụng' => context.tr('Đang sử dụng', 'In use'),
      'Sẵn sàng' => context.tr('Sẵn sàng', 'Ready'),
      'Đã mở khóa' => context.tr('Đã mở khóa', 'Unlocked'),
      _ => vehicle.status,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.pedal_bike, color: Color(0xFF1557FF), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusLabel - ${vehicle.batteryPercent}% ${context.tr('pin', 'battery')}',
                  style: TextStyle(
                    color: _batteryColor(vehicle.batteryPercent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _BatteryBadge(percent: vehicle.batteryPercent),
        ],
      ),
    );
  }

  Color _batteryColor(int percent) {
    if (percent >= 60) return AppColors.success;
    if (percent >= 25) return AppColors.warning;
    return AppColors.danger;
  }
}

class _BatteryBadge extends StatelessWidget {
  final int percent;

  const _BatteryBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 60
        ? AppColors.success
        : percent >= 25
        ? AppColors.warning
        : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
