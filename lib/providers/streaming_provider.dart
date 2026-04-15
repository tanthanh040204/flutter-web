import 'package:flutter/foundation.dart';
import '../models/route_point.dart';

/// ============================================
/// STREAMING PROVIDER - Quản lý streaming realtime
/// ============================================

class StreamingProvider extends ChangeNotifier {
  // Current streaming data
  RoutePoint? _currentPoint;
  bool _isStreaming = false;

  // Statistics
  double _maxSpeed = 0;
  double _avgSpeed = 0;
  double _totalDistance = 0;
  int _pointsReceived = 0;
  DateTime? _streamStartTime;

  // Speed history for average calculation
  final List<double> _speedHistory = [];
  static const int _maxSpeedHistorySize = 100;

  // Streamed points history
  final List<RoutePoint> _streamedPoints = [];

  // Getters
  RoutePoint? get currentPoint => _currentPoint;
  bool get isStreaming => _isStreaming;
  double get maxSpeed => _maxSpeed;
  double get avgSpeed => _avgSpeed;
  double? get averageSpeed => _avgSpeed > 0 ? _avgSpeed : null;
  double get totalDistance => _totalDistance;
  int get pointsReceived => _pointsReceived;
  DateTime? get streamStartTime => _streamStartTime;
  List<RoutePoint> get streamedPoints => List.unmodifiable(_streamedPoints);

  // Computed
  double? get currentSpeed => _currentPoint?.speed;
  double? get currentAltitude => _currentPoint?.altitude;
  double? get currentHeading => _currentPoint?.heading;
  double? get currentAccuracy => _currentPoint?.accuracy;
  String? get currentCoords => _currentPoint?.formattedCoords;

  Duration? get streamDuration => _streamStartTime != null
      ? DateTime.now().difference(_streamStartTime!)
      : null;

  Duration? get streamingDuration => streamDuration;

  /// Start streaming session
  void startStreaming() {
    _isStreaming = true;
    _streamStartTime = DateTime.now();
    _resetStats();
    notifyListeners();
  }

  /// Stop streaming session
  void stopStreaming() {
    _isStreaming = false;
    notifyListeners();
  }

  /// Update with new point from Bluetooth
  void updateCurrentPoint(RoutePoint point) {
    final previousPoint = _currentPoint;
    _currentPoint = point;
    _pointsReceived++;
    _streamedPoints.add(point);

    // Update speed stats
    if (point.speed != null) {
      _updateSpeedStats(point.speed!);
    }

    // Calculate distance from previous point
    if (previousPoint != null) {
      _totalDistance += _calculateDistance(previousPoint, point);
    }

    notifyListeners();
  }

  /// Update speed statistics
  void _updateSpeedStats(double speed) {
    // Update max
    if (speed > _maxSpeed) {
      _maxSpeed = speed;
    }

    // Update history for average
    _speedHistory.add(speed);
    if (_speedHistory.length > _maxSpeedHistorySize) {
      _speedHistory.removeAt(0);
    }

    // Calculate average
    if (_speedHistory.isNotEmpty) {
      _avgSpeed = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
    }
  }

  /// Calculate distance between two points (Haversine)
  double _calculateDistance(RoutePoint p1, RoutePoint p2) {
    const double earthRadius = 6371.0; // km

    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLng = _toRadians(p2.longitude - p1.longitude);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(p1.latitude)) *
            _cos(_toRadians(p2.latitude)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * 3.141592653589793 / 180;
  double _sin(double x) => _mathSin(x);
  double _cos(double x) => _mathCos(x);
  double _sqrt(double x) => _mathSqrt(x);
  double _atan2(double y, double x) => _mathAtan2(y, x);

  // Import math functions manually to avoid dart:math import issues
  static double _mathSin(double x) {
    // Taylor series approximation
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _mathCos(double x) {
    return _mathSin(x + 3.141592653589793 / 2);
  }

  static double _mathSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _mathAtan2(double y, double x) {
    if (x > 0) return _mathAtan(y / x);
    if (x < 0 && y >= 0) return _mathAtan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _mathAtan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _mathAtan(double x) {
    // Taylor series for atan
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 3.141592653589793 / 2 - _mathAtan(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  /// Reset all stats
  void _resetStats() {
    _maxSpeed = 0;
    _avgSpeed = 0;
    _totalDistance = 0;
    _pointsReceived = 0;
    _speedHistory.clear();
    _streamedPoints.clear();
  }

  /// Clear streamed points
  void clearStreamedPoints() {
    _streamedPoints.clear();
    _resetStats();
    notifyListeners();
  }

  /// Clear all data
  void clearAll() {
    _currentPoint = null;
    _isStreaming = false;
    _streamStartTime = null;
    _resetStats();
    notifyListeners();
  }
}
