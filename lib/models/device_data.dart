// @file       device_data.dart
// @brief      Data model for Device Data.

/* Public classes ----------------------------------------------------- */
class DeviceData {
  // ---- GPS ----
  final double? lat;
  final double? lng;
  final DateTime timestamp;

  // ---- Telemetry ----
  final double? battery; // %
  final double? velocityMs; // m/s
  final double? velocityKmh; // km/h
  final double? distanceM; // m
  final double?
  totalKm; // cumulative odometer (km), persisted across power cycles
  final double? directionDeg; // degrees (0-360)
  final String? directionStr; // "NE", "SE", …
  final double? dust; // µg/m³
  final double? temp; // C
  final double? hum; // %

  // Debug fields (not from device, but useful for development)
  // ---- Fusion – Accelerometer ----
  final double? accRx;
  final double? accRy;
  final double? accRz;
  final double? accFx;
  final double? accFy;
  final double? accFz;

  // ---- Fusion – Gyroscope ----
  final double? gyrRx;
  final double? gyrRy;
  final double? gyrRz;
  final double? gyrFx;
  final double? gyrFy;
  final double? gyrFz;

  // ---- Fusion – Compass ----
  final double? cmpRx;
  final double? cmpRy;
  final double? cmpRz;
  final double? cmpFx;
  final double? cmpFy;
  final double? cmpFz;

  // ---- Fusion – INS / GPS velocity & distance ----
  final double? vIns; // m/s
  final double? vGps; // m/s
  final double? dIns; // m
  final double? dGps; // m

  const DeviceData({
    this.lat,
    this.lng,
    required this.timestamp,
    this.battery,
    this.velocityMs,
    this.velocityKmh,
    this.distanceM,
    this.totalKm,
    this.directionDeg,
    this.directionStr,
    this.dust,
    this.temp,
    this.hum,
    this.accRx,
    this.accRy,
    this.accRz,
    this.accFx,
    this.accFy,
    this.accFz,
    this.gyrRx,
    this.gyrRy,
    this.gyrRz,
    this.gyrFx,
    this.gyrFy,
    this.gyrFz,
    this.cmpRx,
    this.cmpRy,
    this.cmpRz,
    this.cmpFx,
    this.cmpFy,
    this.cmpFz,
    this.vIns,
    this.vGps,
    this.dIns,
    this.dGps,
  });

  // true if both lat and lng are not null
  bool get hasGps => lat != null && lng != null;

  // true if there is at least 1 Fusion field
  bool get hasFusion =>
      accRx != null || gyrRx != null || cmpRx != null || vIns != null;
}

/* End of file -------------------------------------------------------- */
