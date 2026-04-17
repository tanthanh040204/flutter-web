// @file       route_provider.dart
// @brief      State provider for Route.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/foundation.dart';
import '../models/route_point.dart';
import '../services/file_service.dart';
import '../utils/geo_utils.dart';

/* Public classes ----------------------------------------------------- */
class RouteProvider extends ChangeNotifier {
  List<RoutePoint> _points = [];
  bool _isLoading = false;
  String? _error;
  String? _fileName;
  bool _showMarkers = true;
  bool _realtimeMode = true;

  // Getters
  List<RoutePoint> get points => List.unmodifiable(_points);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get fileName => _fileName;
  bool get showMarkers => _showMarkers;
  bool get realtimeMode => _realtimeMode;
  bool get hasRoute => _points.isNotEmpty;
  int get pointCount => _points.length;

  // Computed properties
  double get totalDistance => GeoUtils.calculateTotalDistance(_points);

  DateTime? get startTime =>
      _points.isNotEmpty ? _points.first.timestamp : null;

  DateTime? get endTime => _points.isNotEmpty ? _points.last.timestamp : null;

  RoutePoint? get firstPoint => _points.isNotEmpty ? _points.first : null;

  RoutePoint? get lastPoint => _points.isNotEmpty ? _points.last : null;

  // Load route từ file picker
  Future<void> loadFromFilePicker() async {
    _setLoading(true);
    _clearError();

    try {
      final points = await FileService.pickAndReadFile();
      _points = points;
      _fileName = 'Selected file';
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load sample data
  Future<void> loadSampleData() async {
    _setLoading(true);
    _clearError();

    try {
      final points = await FileService.loadSampleData();
      _points = points;
      _fileName = 'sample_route.json';
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load route từ đường dẫn
  Future<void> loadFromPath(String path) async {
    _setLoading(true);
    _clearError();

    try {
      final points = await FileService.loadFromAssets(path);
      _points = points;
      _fileName = path.split('/').last;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Set points directly (từ Bluetooth)
  void setPoints(List<RoutePoint> points) {
    _points = List.from(points);
    _fileName = 'Bluetooth data';
    notifyListeners();
  }

  // Add single point (realtime mode)
  void addPoint(RoutePoint point) {
    _points.add(point);
    notifyListeners();
  }

  // Clear route
  void clearRoute() {
    _points = [];
    _fileName = null;
    _clearError();
    notifyListeners();
  }

  // Toggle show markers
  void toggleMarkers() {
    _showMarkers = !_showMarkers;
    notifyListeners();
  }

  // Set show markers
  void setShowMarkers(bool value) {
    _showMarkers = value;
    notifyListeners();
  }

  // Toggle realtime mode
  void toggleRealtimeMode() {
    _realtimeMode = !_realtimeMode;
    notifyListeners();
  }

  // Set realtime mode
  void setRealtimeMode(bool value) {
    _realtimeMode = value;
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

/* End of file -------------------------------------------------------- */
