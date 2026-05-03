import 'package:latlong2/latlong.dart';

class StationVehicleInfo {
  final String code;
  final int batteryPercent;
  final String status;

  const StationVehicleInfo({
    required this.code,
    required this.batteryPercent,
    required this.status,
  });

  StationVehicleInfo copyWith({
    String? code,
    int? batteryPercent,
    String? status,
  }) {
    return StationVehicleInfo(
      code: code ?? this.code,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      status: status ?? this.status,
    );
  }
}

class BikeStation {
  final String id;
  final String name;
  final String address;
  final String city;
  final LatLng point;
  final int bikeCount;
  final int availableSlots;
  final String googleMapUrl;
  final List<StationVehicleInfo> vehicles;
  final bool isActive;

  const BikeStation({
    required this.id,
    required this.name,
    required this.address,
    this.city = '',
    required this.point,
    required this.bikeCount,
    required this.availableSlots,
    required this.googleMapUrl,
    this.vehicles = const [],
    this.isActive = true,
  });
}
