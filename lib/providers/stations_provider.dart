import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/station.dart';

class StationsProvider extends ChangeNotifier {
  LatLng _currentUserLocation = const LatLng(10.7769, 106.7009);
  List<BikeStation> _stations = const [];

  LatLng get currentUserLocation => _currentUserLocation;
  List<BikeStation> get stations => _stations;

  StationsProvider() {
    _loadDemoStations();
  }

  void _loadDemoStations() {
    _stations = const [
      BikeStation(
        id: 'ST001',
        name: '048 - Trạm Ga Metro Bến Thành',
        address: '20 Lê Lai, Phường Bến Thành, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7726, 106.6980),
        bikeCount: 12,
        availableSlots: 8,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7726,106.6980',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-001',
            batteryPercent: 94,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-002',
            batteryPercent: 72,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-003',
            batteryPercent: 68,
            status: 'Sẵn sàng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST002',
        name: 'Công viên 30/4',
        address: 'Lê Duẩn, Phường Bến Nghé, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7791, 106.6998),
        bikeCount: 10,
        availableSlots: 10,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7791,106.6998',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-004',
            batteryPercent: 17,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-005',
            batteryPercent: 23,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-006',
            batteryPercent: 99,
            status: 'Sẵn sàng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST003',
        name: 'Trống Đồng',
        address:
            '12B Cách Mạng Tháng 8, Phường Bến Thành, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7735, 106.6938),
        bikeCount: 13,
        availableSlots: 6,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7735,106.6938',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-007',
            batteryPercent: 88,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-008',
            batteryPercent: 75,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-009',
            batteryPercent: 52,
            status: 'Đang sạc',
          ),
        ],
      ),
      BikeStation(
        id: 'ST004',
        name: 'Sở Y Tế',
        address:
            '59 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7761, 106.6927),
        bikeCount: 5,
        availableSlots: 14,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7761,106.6927',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-010',
            batteryPercent: 81,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-011',
            batteryPercent: 64,
            status: 'Sẵn sàng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST005',
        name: 'Công viên Tao Đàn',
        address: 'Trương Định, Phường Bến Thành, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7747, 106.6919),
        bikeCount: 13,
        availableSlots: 2,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7747,106.6919',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-012',
            batteryPercent: 96,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-013',
            batteryPercent: 45,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-014',
            batteryPercent: 33,
            status: 'Tạm ngưng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST006',
        name: 'Cung Văn hóa Lao Động',
        address:
            '57 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7758, 106.6944),
        bikeCount: 3,
        availableSlots: 20,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7758,106.6944',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-015',
            batteryPercent: 55,
            status: 'Sẵn sàng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST007',
        name: 'Nhà thờ Đức Bà',
        address: '01 Công xã Paris, Phường Bến Nghé, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7798, 106.6990),
        bikeCount: 16,
        availableSlots: 4,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7798,106.6990',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-016',
            batteryPercent: 89,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-017',
            batteryPercent: 92,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-018',
            batteryPercent: 21,
            status: 'Sẵn sàng',
          ),
        ],
      ),
      BikeStation(
        id: 'ST008',
        name: 'Vincom Đồng Khởi',
        address: '72 Lê Thánh Tôn, Phường Bến Nghé, Quận 1, TP Hồ Chí Minh',
        city: 'TP.HCM',
        point: LatLng(10.7782, 106.7032),
        bikeCount: 11,
        availableSlots: 7,
        googleMapUrl:
            'https://www.google.com/maps/search/?api=1&query=10.7782,106.7032',
        vehicles: [
          StationVehicleInfo(
            code: 'haq-trk-019',
            batteryPercent: 77,
            status: 'Sẵn sàng',
          ),
          StationVehicleInfo(
            code: 'haq-trk-020',
            batteryPercent: 59,
            status: 'Đang sạc',
          ),
        ],
      ),
    ];

    notifyListeners();
  }

  Future<void> refreshUserLocation() async {
    // Demo: giữ vị trí trung tâm Quận 1 để nhìn rõ cụm trạm.
    // Có thể thay bằng geolocator sau nếu web cần lấy GPS thật.
    _currentUserLocation = const LatLng(10.7769, 106.7009);
    notifyListeners();
  }
}
