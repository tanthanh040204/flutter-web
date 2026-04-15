import 'package:latlong2/latlong.dart';

/// ============================================
/// MODEL: Route Point
/// ============================================

class RoutePoint {
  final double latitude;
  final double longitude;
  final String? name;
  final String? description;
  final DateTime? timestamp;
  final double? speed; // km/h
  final double? altitude; // meters
  final double? heading; // degrees (0-360)
  final double? accuracy; // meters

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.name,
    this.description,
    this.timestamp,
    this.speed,
    this.altitude,
    this.heading,
    this.accuracy,
  });

  /// Convert to LatLng for flutter_map
  LatLng get latLng => LatLng(latitude, longitude);

  /// Create from JSON
  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: _parseDouble(json['lat'] ?? json['latitude'] ?? json['y']),
      longitude: _parseDouble(
          json['lng'] ?? json['lon'] ?? json['longitude'] ?? json['x']),
      name: json['name'] as String?,
      description: json['description'] ?? json['desc'] as String?,
      timestamp: _parseDateTime(json['timestamp'] ?? json['time']),
      speed: _parseDoubleOrNull(json['speed'] ?? json['spd']),
      altitude: _parseDoubleOrNull(
          json['altitude'] ?? json['alt'] ?? json['elevation']),
      heading: _parseDoubleOrNull(
          json['heading'] ?? json['bearing'] ?? json['course']),
      accuracy: _parseDoubleOrNull(json['accuracy'] ?? json['acc']),
    );
  }

  /// Create from CSV line
  factory RoutePoint.fromCsvLine(String line, List<String> headers) {
    final values = line.split(',').map((e) => e.trim()).toList();
    final map = <String, dynamic>{};

    for (var i = 0; i < headers.length && i < values.length; i++) {
      map[headers[i].toLowerCase()] = values[i];
    }

    return RoutePoint.fromJson(map);
  }

  /// Create from simple "lat,lng" format
  factory RoutePoint.fromSimpleLine(String line) {
    final parts =
        line.split(RegExp(r'[,\s\t]+')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) {
      throw FormatException('Invalid line format: $line');
    }

    return RoutePoint(
      latitude: double.parse(parts[0]),
      longitude: double.parse(parts[1]),
      name: parts.length > 2 ? parts[2] : null,
      timestamp: DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (speed != null) 'speed': speed,
      if (altitude != null) 'altitude': altitude,
      if (heading != null) 'heading': heading,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }

  /// Validate coordinates
  bool get isValid {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// Format coordinates as string
  String get formattedCoords =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// Display name (name or coordinates)
  String get displayName => name ?? formattedCoords;

  @override
  String toString() => 'RoutePoint($latitude, $longitude, $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutePoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  // Helper methods
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.parse(value);
    throw FormatException('Cannot parse $value as double');
  }

  static double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
