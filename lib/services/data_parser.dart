// @file       data_parser.dart
// @brief      Service for Data Parser.

/* Imports ------------------------------------------------------------ */
import 'dart:convert';
import 'dart:developer' as dev;

import '../config/feature_config.dart';
import '../models/device_data.dart';

// DataParser
// Parse MCU MQTT payload (quasi-JSON) → DeviceData.
// MCU send json:
//   {"battery":100.0,"time":[2026/4/9-22:51:35],"velocity_ms":0.00,
//    "velocity_kmh":0.00,"distance_m":0.0,"direction":"139.0 SE",
//    "position":(10.853061,106.782814),"dust":0.0,"temp":0.0,"hum":0.0}
//
// ============================================================
// How to extend parser for new fields:
//   1. TAdd field vào DeviceData.
//   2. Add toDouble(json['key']) in _normalize().
//   3. If format is special → parse in special function: _parseTime().
// ============================================================
/* Public classes ----------------------------------------------------- */
class DataParser {
  const DataParser._();

  // Parse raw MQTT payload → DeviceData | null
  static DeviceData? parse(String raw) {
    if (raw.isEmpty) return null;
    try {
      final fixed = _preProcess(raw.trim());
      final dynamic decoded = jsonDecode(fixed);
      if (decoded is! Map<String, dynamic>) return null;
      return _normalize(decoded);
    } catch (e) {
      if (FeatureConfig.debugParserLog) {
        final preview = raw.length > 120 ? raw.substring(0, 120) : raw;
        dev.log(
          '[DataParser] Parse failed: $e\n  Raw(120): $preview',
          name: 'DataParser',
        );
      }
      return null;
    }
  }

  // Pre-process raw string to fix common MCU formatting issues before JSON parsing.
  // Transforms ( JS _preProcess):
  //   "time":[2026/4/9-22:51:35]        → "time":"2026/4/9-22:51:35"
  //   "direction":45.0 NE               → "direction":"45.0 NE"
  //   "position":(10.853061,106.782814) → "position":"(10.853061,...)"
  //   :nan / :NaN                        → :null
  static String _preProcess(String s) {
    // -1. Add {} if needed
    if (!s.startsWith('{') && !s.endsWith('}')) {
      s = '{$s}';
    } else if (!s.startsWith('{')) {
      s = '{$s';
    } else if (!s.endsWith('}')) {
      s = '$s}';
    }

    // 0. Fix split-JSON: },<fusion_field> → ,<fusion_field>
    //    MCU sometimes sends {...,"hum":0.0},"acc_rx":...}
    s = s.replaceAllMapped(
      RegExp(r'\}\s*,\s*"(acc_|gyr_|cmp_|v_ins|v_gps|d_ins|d_gps)'),
      (m) => ',"${m.group(1)}',
    );

    // 1. time:[...] → "time":"..."
    s = s.replaceAllMapped(
      RegExp(r'"time"\s*:\s*\[([^\]]*)\]'),
      (m) => '"time":"${m.group(1)}"',
    );

    // 2. direction: <number> <LETTERS> → "direction":"<number> <LETTERS>"
    //    Chỉ transform khi chưa được quote
    s = s.replaceAllMapped(
      RegExp(r'"direction"\s*:\s*([\d.]+)\s+([A-Z?]+)(?=[,}])'),
      (m) => '"direction":"${m.group(1)} ${m.group(2)}"',
    );

    // 3. position:(...) → "position":"(...)"
    s = s.replaceAllMapped(
      RegExp(r'"position"\s*:\s*\(([^)]+)\)'),
      (m) => '"position":"(${m.group(1)})"',
    );

    // 4. NaN tokens from firmware → null
    s = s.replaceAll(RegExp(r':\s*[+-]?nan\b', caseSensitive: false), ':null');

    return s;
  }

  static DeviceData _normalize(Map<String, dynamic> json) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    // ---- Position ----
    double? lat, lng;
    final rawPos = json['position'];
    if (rawPos != null) {
      if (rawPos is List) {
        final pos = _parsePositionArray(rawPos);
        lat = pos?.$1;
        lng = pos?.$2;
      } else {
        final pos = _parsePositionString(rawPos.toString());
        lat = pos?.$1;
        lng = pos?.$2;
      }
    }

    // ---- Time ----
    DateTime timestamp = DateTime.now();
    final rawTime = json['time'];
    if (rawTime != null) {
      timestamp = _parseTime(rawTime.toString()) ?? DateTime.now();
    }

    // ---- Direction ----
    double? directionDeg;
    String? directionStr;
    final rawDir = json['direction'];
    if (rawDir != null) {
      final dir = _parseDirection(rawDir.toString());
      directionDeg = dir?.$1;
      directionStr = dir?.$2;
    }

    final fusion = FeatureConfig.enableFusionData;

    return DeviceData(
      lat: lat,
      lng: lng,
      timestamp: timestamp,
      battery: toD(json['battery']),
      velocityMs: toD(json['velocity_ms']) ?? toD(json['speed_ms']),
      velocityKmh: toD(json['velocity_kmh']) ??
          toD(json['speed_kmh']) ??
          toD(json['speed']),
      distanceM: toD(json['distance_m']) ??
          toD(json['distance']) ??
          toD(json['dist_m']) ??
          toD(json['odo_m']),
      totalKm: toD(json['totalKm']) ?? toD(json['total_km']),
      directionDeg: directionDeg,
      directionStr: directionStr,
      dust: toD(json['dust']),
      temp: toD(json['temp']),
      hum: toD(json['hum']),
      // Fusion – Accelerometer
      accRx: fusion ? toD(json['acc_rx']) : null,
      accRy: fusion ? toD(json['acc_ry']) : null,
      accRz: fusion ? toD(json['acc_rz']) : null,
      accFx: fusion ? toD(json['acc_fx']) : null,
      accFy: fusion ? toD(json['acc_fy']) : null,
      accFz: fusion ? toD(json['acc_fz']) : null,
      // Fusion – Gyroscope
      gyrRx: fusion ? toD(json['gyr_rx']) : null,
      gyrRy: fusion ? toD(json['gyr_ry']) : null,
      gyrRz: fusion ? toD(json['gyr_rz']) : null,
      gyrFx: fusion ? toD(json['gyr_fx']) : null,
      gyrFy: fusion ? toD(json['gyr_fy']) : null,
      gyrFz: fusion ? toD(json['gyr_fz']) : null,
      // Fusion – Compass
      cmpRx: fusion ? toD(json['cmp_rx']) : null,
      cmpRy: fusion ? toD(json['cmp_ry']) : null,
      cmpRz: fusion ? toD(json['cmp_rz']) : null,
      cmpFx: fusion ? toD(json['cmp_fx']) : null,
      cmpFy: fusion ? toD(json['cmp_fy']) : null,
      cmpFz: fusion ? toD(json['cmp_fz']) : null,
      // Fusion – INS/GPS
      vIns: fusion ? toD(json['v_ins']) : null,
      vGps: fusion ? toD(json['v_gps']) : null,
      dIns: fusion ? toD(json['d_ins']) : null,
      dGps: fusion ? toD(json['d_gps']) : null,
    );
  }

  // Parse [lat, lng] array (new MCU format) → (lat, lng) | null
  static (double, double)? _parsePositionArray(List<dynamic> arr) {
    if (arr.length < 2) return null;
    final lat = double.tryParse(arr[0].toString());
    final lng = double.tryParse(arr[1].toString());
    if (lat == null || lng == null || lat.isNaN || lng.isNaN) return null;
    if (lat == 0 && lng == 0) return null; // chưa có GPS fix
    return (lat, lng);
  }

  // Parse "(lat,lng)" string (new MCU format) → (lat, lng) | null
  static (double, double)? _parsePositionString(String str) {
    final m = RegExp(r'\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)').firstMatch(str);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null || lat.isNaN || lng.isNaN) return null;
    if (lat == 0 && lng == 0) return null;
    return (lat, lng);
  }

  // Parse "45.0 NE" hoặc "45.0" → (deg, str) | null
  static (double, String)? _parseDirection(String str) {
    final m = RegExp(r'^([\d.]+)\s*([A-Z?]*)$').firstMatch(str.trim());
    if (m == null) return null;
    final deg = double.tryParse(m.group(1)!);
    if (deg == null) return null;
    return (deg, m.group(2) ?? '');
  }

  // Parse time string → DateTime | null
  // Support 2 format MCU:
  //   Mới: YYYY/M/D-HH:MM:SS   (e.g. 2026/4/9-22:51:35)
  //   Cũ:  DD/MM/YYYY-HH:MM:SS (e.g. 25/3/2026-10:30:00)
  // If first component > 31 then it's the year (new format).
  static DateTime? _parseTime(String str) {
    final m = RegExp(r'(\d+)/(\d+)/(\d+)-(\d+):(\d+):(\d+)').firstMatch(str);
    if (m == null) return null;

    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = int.parse(m.group(6)!);

    int y, mo, d;
    if (a > 31) {
      // New format: YYYY/M/D
      y = a;
      mo = b;
      d = c;
    } else {
      // Old format: DD/MM/YYYY
      d = a;
      mo = b;
      y = c;
    }

    // Sentinel "no GPS fix"
    if (y <= 2000 || mo == 0 || d == 0) return null;

    try {
      final dt = DateTime(y, mo, d, h, mi, s);
      return dt;
    } catch (_) {
      return null;
    }
  }
}

/* End of file -------------------------------------------------------- */
