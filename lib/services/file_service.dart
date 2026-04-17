// @file       file_service.dart
// @brief      Service for File.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../config/app_constants.dart';
import '../models/route_point.dart';

/* Public classes ----------------------------------------------------- */
class FileService {
  FileService._();

  // Choose and read file from device (web-safe)
  static Future<List<RoutePoint>> pickAndReadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileConfig.supportedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('Không có file được chọn');
    }

    final file = result.files.first;

    if (file.size > FileConfig.maxFileSizeBytes) {
      throw Exception(
        'File quá lớn (max ${FileConfig.maxFileSizeBytes ~/ 1024 ~/ 1024}MB)',
      );
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception(
        'Không thể đọc file. Hãy bật withData hoặc chọn lại file.',
      );
    }

    final content = utf8.decode(bytes);
    return parseContent(content, file.extension ?? '');
  }

  // Load file from assets
  static Future<List<RoutePoint>> loadFromAssets(String path) async {
    try {
      final content = await rootBundle.loadString(path);
      final extension = path.split('.').last.toLowerCase();
      return parseContent(content, extension);
    } catch (e) {
      throw Exception('Không thể đọc file: $path');
    }
  }

  static Future<List<RoutePoint>> loadSampleData() async {
    return loadFromAssets(FileConfig.defaultFilePath);
  }

  static List<RoutePoint> parseContent(String content, String extension) {
    switch (extension.toLowerCase()) {
      case 'json':
        return parseJson(content);
      case 'csv':
        return parseCsv(content);
      case 'txt':
        return parseTxt(content);
      default:
        try {
          return parseJson(content);
        } catch (_) {
          return parseCsv(content);
        }
    }
  }

  static List<RoutePoint> parseJson(String content) {
    final data = jsonDecode(content);

    List<dynamic> pointsList;

    if (data is List) {
      pointsList = data;
    } else if (data is Map) {
      pointsList =
          data['points'] ??
          data['route'] ??
          data['coordinates'] ??
          data['path'] ??
          [];

      if (data['type'] == 'FeatureCollection') {
        return _parseGeoJson(Map<String, dynamic>.from(data));
      }
      if (data['type'] == 'Feature') {
        return _parseGeoJson(<String, dynamic>{
          'type': 'FeatureCollection',
          'features': [data],
        });
      }
    } else {
      throw FormatException('Invalid JSON format');
    }

    final points = pointsList
        .map((item) => RoutePoint.fromJson(item as Map<String, dynamic>))
        .toList();

    return _validatePoints(points);
  }

  static List<RoutePoint> _parseGeoJson(Map<String, dynamic> geojson) {
    final points = <RoutePoint>[];
    final features = geojson['features'] as List;

    for (final feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'];

      if (type == 'Point') {
        points.add(
          RoutePoint(
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
            name: properties['name'] as String?,
          ),
        );
      } else if (type == 'LineString') {
        for (final coord in coords) {
          points.add(
            RoutePoint(
              latitude: (coord[1] as num).toDouble(),
              longitude: (coord[0] as num).toDouble(),
            ),
          );
        }
      }
    }

    return _validatePoints(points);
  }

  static List<RoutePoint> parseCsv(String content) {
    final lines = content.trim().split('\n');
    if (lines.length < 2) {
      throw FormatException('CSV file is empty or missing header');
    }

    final headers = lines.first
        .split(',')
        .map((h) => h.trim().toLowerCase())
        .toList();

    final latIndex = headers.indexWhere(
      (h) => ['lat', 'latitude', 'y'].contains(h),
    );
    final lngIndex = headers.indexWhere(
      (h) => ['lng', 'lon', 'longitude', 'x'].contains(h),
    );

    if (latIndex == -1 || lngIndex == -1) {
      throw FormatException(
        'CSV file must have lat/latitude and lng/lon/longitude columns',
      );
    }

    final points = <RoutePoint>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        points.add(RoutePoint.fromCsvLine(line, headers));
      } catch (_) {
        // Skip invalid lines
      }
    }

    return _validatePoints(points);
  }

  static List<RoutePoint> parseTxt(String content) {
    final lines = content.trim().split('\n');
    final points = <RoutePoint>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      try {
        points.add(RoutePoint.fromSimpleLine(trimmed));
      } catch (_) {
        // Skip invalid lines
      }
    }

    return _validatePoints(points);
  }

  static List<RoutePoint> _validatePoints(List<RoutePoint> points) {
    final validPoints = points.where((p) => p.isValid).toList();

    if (validPoints.isEmpty) {
      throw Exception('No valid coordinates found in the file');
    }

    return validPoints;
  }
}

/* End of file -------------------------------------------------------- */
