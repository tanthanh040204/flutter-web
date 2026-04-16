import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/vehicle_picker.dart';
import '../../providers/fleet_provider.dart';

class ChargingStation {
  final String name;
  final LatLng point;
  final String note;

  const ChargingStation({
    required this.name,
    required this.point,
    required this.note,
  });
}

const List<ChargingStation> kFixedChargingStations = [
  ChargingStation(
    name: 'Trạm sạc Bến Bạch Đằng',
    point: LatLng(10.7749, 106.7056),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Nguyễn Huệ',
    point: LatLng(10.7737, 106.7042),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Nhà hát TP',
    point: LatLng(10.7765, 106.7030),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Chợ Bến Thành',
    point: LatLng(10.7724, 106.6981),
    note: '24/7',
  ),
  ChargingStation(
    name: 'Trạm sạc Bitexco',
    point: LatLng(10.7717, 106.7041),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Vincom Đồng Khởi',
    point: LatLng(10.7780, 106.7050),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Landmark 81',
    point: LatLng(10.7949, 106.7218),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Sala',
    point: LatLng(10.7805, 106.7268),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Thảo Điền',
    point: LatLng(10.8032, 106.7318),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Phú Mỹ Hưng',
    point: LatLng(10.7298, 106.7215),
    note: '24/7',
  ),

  // =========================
  // Hà Nội - 10 điểm
  // =========================
  ChargingStation(
    name: 'Trạm sạc Hồ Gươm',
    point: LatLng(21.030679, 105.85358),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Nhà hát Lớn',
    point: LatLng(21.0245, 105.8570),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Tràng Tiền Plaza',
    point: LatLng(21.0240, 105.8553),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Lăng Bác',
    point: LatLng(21.0368, 105.8348),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Vincom Bà Triệu',
    point: LatLng(21.0129, 105.8494),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Times City',
    point: LatLng(20.9956, 105.8688),
    note: '24/7',
  ),
  ChargingStation(
    name: 'Trạm sạc Royal City',
    point: LatLng(21.0023, 105.8153),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Mỹ Đình',
    point: LatLng(21.0285, 105.7808),
    note: 'Sạc thường',
  ),
  ChargingStation(
    name: 'Trạm sạc Cầu Giấy',
    point: LatLng(21.0362, 105.7905),
    note: 'Sạc nhanh',
  ),
  ChargingStation(
    name: 'Trạm sạc Long Biên',
    point: LatLng(21.0453, 105.8898),
    note: '24/7',
  ),
];

class LocationTab extends StatelessWidget {
  const LocationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<FleetProvider>().selectedOrNull;
    if (v == null) {
      return const Scaffold(
        body: Center(child: Text('Chưa có xe nào trong Firebase.')),
      );
    }

    final LatLng loc = v.lastLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Địa điểm'),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: loc, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.route_tracker',
          ),

          // Marker xe hiện tại
          MarkerLayer(
            markers: [
              Marker(
                point: loc,
                width: 150,
                height: 99,
                child: const Icon(
                  Icons.electric_car, //location_on,
                  size: 44,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          // Các trạm sạc cố định
          MarkerLayer(
            markers: kFixedChargingStations.map((station) {
              return Marker(
                point: station.point,
                width: 150,
                height: 90,
                child: const Icon(
                  Icons.charging_station,
                  size: 44,
                  color: Color.fromARGB(255, 111, 244, 74),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reloading')));
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Cập nhật'),
      ),
    );
  }
}

class _ChargingStationMarker extends StatelessWidget {
  final ChargingStation station;

  const _ChargingStationMarker({required this.station});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            station.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            station.note,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Icon(Icons.ev_station, color: Colors.green, size: 34),
      ],
    );
  }
}
