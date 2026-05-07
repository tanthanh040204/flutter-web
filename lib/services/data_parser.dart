// @file       data_parser.dart
// @brief      Service for Data Parser.

/* Imports ------------------------------------------------------------ */
import 'dart:convert';
import 'dart:developer' as dev;

import '../config/feature_config.dart';
import '../models/device_data.dart';

// DataParser
// Parse MCU MQTT payload (standard JSON) → DeviceData.
//
// Expected payload (firmware v2):
//   {"time":"2026/05/07-22:38:21","battery":46.6,
//    "velocity_ms":0.0,"velocity_kmh":0.0,"distance_m":0.0,"totalKm":0.0,
//    "direction_deg":233.0,"direction_str":"SW",
//    "position":[10.853079,106.782715],
//    "dust":0.7,"temp":33.1,"hum":67.8}
//
// ============================================================
// How to extend parser for new fields:
//   1. Add field to DeviceData.
//   2. Add toDouble(json['key']) in _normalize().
//   3. If format is special → parse in special function: _parseTime().
// ============================================================
/* Public classes ----------------------------------------------------- */
class DataParser {
  const DataParser._();

  /* --- public methods ------------------------------------------ */
  // Parse raw MQTT payload → DeviceData | null.
  static DeviceData? parse(String raw) {
    if (raw.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return _normalize(decoded);
    } catch (e) {
      if (FeatureConfig.debugParserLog) {
        final preview = raw.length > 120 ? raw.substring(0, 120) : raw;
        dev.log(
          '[DataParser] parse failed: $e\n  raw(120): $preview',
          name: 'DataParser',
        );
      }
      return null;
    }
  }

  /* --- private methods ----------------------------------------- */
  static DeviceData _normalize(Map<String, dynamic> json) {
    final bool fusion = FeatureConfig.enableFusionData;

    final (double?, double?) pos = _parsePosition(json['position']);
    final DateTime ts = _parseTime(json['time']?.toString()) ?? DateTime.now();

    return DeviceData(
      lat: pos.$1,
      lng: pos.$2,
      timestamp: ts,
      battery: _toD(json['battery']),
      velocityMs: _toD(json['velocity_ms']),
      velocityKmh: _toD(json['velocity_kmh']),
      distanceM: _toD(json['distance_m']),
      totalKm: _toD(json['totalKm']),
      directionDeg: _toD(json['direction_deg']),
      directionStr: json['direction_str']?.toString(),
      dust: _toD(json['dust']),
      temp: _toD(json['temp']),
      hum: _toD(json['hum']),
      // Fusion – Accelerometer
      accRx: fusion ? _toD(json['acc_rx']) : null,
      accRy: fusion ? _toD(json['acc_ry']) : null,
      accRz: fusion ? _toD(json['acc_rz']) : null,
      accFx: fusion ? _toD(json['acc_fx']) : null,
      accFy: fusion ? _toD(json['acc_fy']) : null,
      accFz: fusion ? _toD(json['acc_fz']) : null,
      // Fusion – Gyroscope
      gyrRx: fusion ? _toD(json['gyr_rx']) : null,
      gyrRy: fusion ? _toD(json['gyr_ry']) : null,
      gyrRz: fusion ? _toD(json['gyr_rz']) : null,
      gyrFx: fusion ? _toD(json['gyr_fx']) : null,
      gyrFy: fusion ? _toD(json['gyr_fy']) : null,
      gyrFz: fusion ? _toD(json['gyr_fz']) : null,
      // Fusion – Compass
      cmpRx: fusion ? _toD(json['cmp_rx']) : null,
      cmpRy: fusion ? _toD(json['cmp_ry']) : null,
      cmpRz: fusion ? _toD(json['cmp_rz']) : null,
      cmpFx: fusion ? _toD(json['cmp_fx']) : null,
      cmpFy: fusion ? _toD(json['cmp_fy']) : null,
      cmpFz: fusion ? _toD(json['cmp_fz']) : null,
      // Fusion – INS/GPS
      vIns: fusion ? _toD(json['v_ins']) : null,
      vGps: fusion ? _toD(json['v_gps']) : null,
      dIns: fusion ? _toD(json['d_ins']) : null,
      dGps: fusion ? _toD(json['d_gps']) : null,
    );
  }

  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // Parse [lat, lng] array → (lat, lng). Drops (0,0) sentinel "no GPS fix".
  static (double?, double?) _parsePosition(dynamic raw) {
    if (raw is! List || raw.length < 2) return (null, null);
    final double? lat = _toD(raw[0]);
    final double? lng = _toD(raw[1]);
    if (lat == null || lng == null) return (null, null);
    if (lat.isNaN || lng.isNaN) return (null, null);
    if (lat == 0 && lng == 0) return (null, null);
    return (lat, lng);
  }

  // Parse "YYYY/M/D-HH:MM:SS" → DateTime | null.
  static DateTime? _parseTime(String? str) {
    if (str == null || str.isEmpty) return null;
    final m = RegExp(r'(\d+)/(\d+)/(\d+)-(\d+):(\d+):(\d+)').firstMatch(str);
    if (m == null) return null;
    final int y = int.parse(m.group(1)!);
    final int mo = int.parse(m.group(2)!);
    final int d = int.parse(m.group(3)!);
    final int h = int.parse(m.group(4)!);
    final int mi = int.parse(m.group(5)!);
    final int s = int.parse(m.group(6)!);

    // Sentinel "no GPS fix" — firmware sends epoch-ish defaults before lock.
    if (y <= 2000 || mo == 0 || d == 0) return null;

    try {
      return DateTime(y, mo, d, h, mi, s);
    } catch (_) {
      return null;
    }
  }
}

/* End of file -------------------------------------------------------- */
