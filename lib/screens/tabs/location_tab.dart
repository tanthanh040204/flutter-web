import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/vehicle_picker.dart';

import '../../providers/fleet_provider.dart';

class LocationTab extends StatelessWidget {
  const LocationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<FleetProvider>().selectedOrNull;
    if (v == null) {
      return const Scaffold(body: Center(child: Text('Chưa có xe nào trong Firebase.')));
    }

    final LatLng loc = v.lastLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Địa điểm'), actions: const [VehiclePicker(), SizedBox(width: 8)]),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: loc,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.route_tracker',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: loc,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on, size: 44),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vị trí trên bản đồ sẽ đổi khi Firestore cập nhật lastLocation.')),
          );
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Cập nhật'),
      ),
    );
  }
}
