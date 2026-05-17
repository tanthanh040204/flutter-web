// @file       fleet_provider.dart
// @brief      State provider for Fleet.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle.dart';
import '../services/firebase_repo.dart';
import '../services/mqtt_service.dart';

/* Public classes ----------------------------------------------------- */
class FleetProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = [];

  StreamSubscription<List<Vehicle>>? _vehiclesSub;
  MqttService? _mqttService;
  StreamSubscription<MqttVehicleState>? _mqttSub;
  Timer? _historyCloseTimer;
  final Map<String, DateTime> _lastHistoryWriteAt = <String, DateTime>{};
  bool _isClosingStaleHistoryRoutes = false;

  static const Duration _historyWriteInterval = Duration(seconds: 2);
  static const Duration _historyCloseAfter = Duration(seconds: 20);

  int _selectedIndex = 0;
  bool _isSyncing = false;
  bool _isAddingVehicle = false;
  String? _lastError;

  FleetProvider() {
    _historyCloseTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _closeStaleHistoryRoutes(),
    );
  }

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  int get selectedIndex => _vehicles.isEmpty ? 0 : _selectedIndex;
  bool get hasVehicles => _vehicles.isNotEmpty;
  bool get isSyncing => _isSyncing;
  bool get isAddingVehicle => _isAddingVehicle;
  String? get lastError => _lastError;

  Vehicle? get selectedOrNull {
    if (_vehicles.isEmpty) return null;
    if (_selectedIndex < 0 || _selectedIndex >= _vehicles.length) {
      return _vehicles.first;
    }
    return _vehicles[_selectedIndex];
  }

  Vehicle get selected {
    final value = selectedOrNull;
    if (value == null) {
      throw StateError('No vehicles available');
    }
    return value;
  }

  double? get selectedTemp => selectedOrNull?.temp;
  double? get selectedHum => selectedOrNull?.hum;
  double? get selectedDust => selectedOrNull?.dust;
  double? get selectedVelocityKmh => selectedOrNull?.velocityKmh;

  void selectVehicle(int index) {
    if (index < 0 || index >= _vehicles.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  // Add vehicle with 3-digit number — creates ID haq-trk-xxx in Firebase.
  Future<void> addVehicle({required String vehicleNumber}) async {
    if (_isAddingVehicle) return;

    final vehicleId = 'haq-trk-$vehicleNumber';

    _isAddingVehicle = true;
    _lastError = null;
    notifyListeners();

    try {
      await FirebaseRepo.instance.createVehicle(vehicleId: vehicleId);

      final newIndex = _vehicles.indexWhere((v) => v.id == vehicleId);
      if (newIndex >= 0) _selectedIndex = newIndex;
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isAddingVehicle = false;
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await FirebaseRepo.instance.deleteVehicle(vehicleId);

    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index < 0) return;

    _vehicles.removeAt(index);
    if (_selectedIndex >= _vehicles.length) {
      _selectedIndex = _vehicles.isEmpty ? 0 : _vehicles.length - 1;
    }
    notifyListeners();
  }

  Future<void> renameSelected(String name) async {
    final current = selectedOrNull;
    if (current == null) return;

    await _replaceAndPush(
      current.copyWith(name: name, updatedAt: DateTime.now()),
    );
  }

  Future<void> toggleLock() async {
    final current = selectedOrNull;
    if (current == null) return;

    await _replaceAndPush(
      current.copyWith(isLocked: !current.isLocked, updatedAt: DateTime.now()),
    );
  }

  Future<void> setRunning(bool running) async {
    final current = selectedOrNull;
    if (current == null) return;

    await _replaceAndPush(
      current.copyWith(isRunning: running, updatedAt: DateTime.now()),
    );
  }

  Future<void> updateBattery(int percent) async {
    final current = selectedOrNull;
    if (current == null) return;

    await _replaceAndPush(
      current.copyWith(
        batteryPercent: percent.clamp(0, 100).toInt(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateLastLocation(LatLng loc) async {
    final current = selectedOrNull;
    if (current == null) return;

    await _replaceAndPush(
      current.copyWith(lastLocation: loc, updatedAt: DateTime.now()),
    );
  }

  Future<void> addKm(double km) async {
    final current = selectedOrNull;
    if (current == null) return;

    final safeKm = km.clamp(0, double.infinity).toDouble();
    final next = current.copyWith(
      totalKm: (current.totalKm + safeKm).clamp(0, double.infinity).toDouble(),
      updatedAt: DateTime.now(),
    );

    await _replaceAndPush(next);

    try {
      await FirebaseRepo.instance.incrementMaintenanceByDistance(
        current.id,
        safeKm,
      );
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _replaceAndPush(Vehicle next) async {
    final index = _vehicles.indexWhere((v) => v.id == next.id);
    if (index < 0) return;

    _vehicles[index] = next;
    _selectedIndex = index;
    notifyListeners();

    try {
      await FirebaseRepo.instance.saveVehicle(next);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  void bindToFirestore() {
    _vehiclesSub?.cancel();
    _isSyncing = true;
    notifyListeners();

    _vehiclesSub = FirebaseRepo.instance.watchVehicles().listen(
      (remote) {
        _isSyncing = false;
        _lastError = null;

        final previousSelectedId = selectedOrNull?.id;
        _vehicles
          ..clear()
          ..addAll(remote);

        // Auto-subscribe MQTT topics for all vehicles from Firebase
        for (final v in _vehicles) {
          _mqttService?.subscribeDevice(v.id);
        }

        if (_vehicles.isEmpty) {
          _selectedIndex = 0;
        } else {
          final selectedIdx = previousSelectedId == null
              ? -1
              : _vehicles.indexWhere((v) => v.id == previousSelectedId);
          _selectedIndex = selectedIdx >= 0 ? selectedIdx : 0;
        }

        notifyListeners();
      },
      onError: (error) {
        _isSyncing = false;
        _lastError = error.toString();
        notifyListeners();
      },
    );
  }

  void bindToMqtt(MqttService service) {
    _mqttService = service;
    _mqttSub?.cancel();

    // Subscribe topics for vehicles already loaded from Firebase
    for (final v in _vehicles) {
      service.subscribeDevice(v.id);
    }

    _mqttSub = service.vehicleStates.listen(
      (message) {
        applyMqttState(message.payload);
      },
      onError: (error) {
        _lastError = 'MQTT error: $error';
        notifyListeners();
      },
    );
  }

  void applyMqttState(Map<String, dynamic> data) {
    debugPrint('MQTT RX payload: $data');

    final id = (data['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final index = _vehicles.indexWhere((v) => v.id == id);
    if (index < 0) {
      debugPrint('MQTT vehicle id not found in app: $id');
      return;
    }

    final current = _vehicles[index];

    final next = current.copyWith(
      batteryPercent: _toInt(
        data['batteryPercent'],
        current.batteryPercent,
      ).clamp(0, 100).toInt(),
      isLocked: _toBool(data['isLocked'], current.isLocked),
      isRunning: _toBool(data['isRunning'], current.isRunning),
      totalKm: data.containsKey('totalKm')
          ? _toDouble(data['totalKm'], current.totalKm)
          : current.totalKm,
      temp: data.containsKey('temp')
          ? _toDouble(data['temp'], current.temp)
          : current.temp,
      hum: data.containsKey('hum')
          ? _toDouble(data['hum'], current.hum)
          : current.hum,
      dust: data.containsKey('dust')
          ? _toDouble(data['dust'], current.dust)
          : current.dust,
      velocityKmh: data.containsKey('velocityKmh')
          ? _toDouble(data['velocityKmh'], current.velocityKmh)
          : current.velocityKmh,
      lastLocation: LatLng(
        _toDouble(data['lat'], current.lastLocation.latitude),
        _toDouble(data['lon'], current.lastLocation.longitude),
      ),
      updatedAt: DateTime.now(),
    );

    _vehicles[index] = next;
    notifyListeners();

    // Persist latest sensor/location data to Firebase for all devices.
    // The history tab also depends on this MQTT stream. If we only update
    // vehicles/{id}, the History tab can show an old/open route forever.
    FirebaseRepo.instance.saveVehicle(next).catchError((e) {
      debugPrint('[FleetProvider] Firebase save error: $e');
    });

    _persistMqttDerivedData(next, data);
  }

  void sendSetLock(bool locked) {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    mqtt.publishCommand(current.id, {
      'action': locked ? 'lock' : 'unlock',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendSetRunning(bool running) {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    mqtt.publishCommand(current.id, {
      'action': running ? 'start' : 'stop',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void requestHorn() {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    mqtt.publishCommand(current.id, {
      'action': 'horn',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void requestFindVehicle() {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    mqtt.publishCommand(current.id, {
      'action': 'find_vehicle',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _persistMqttDerivedData(Vehicle next, Map<String, dynamic> data) {
    final lat = _toDouble(data['lat'], 0.0);
    final lon = _toDouble(data['lon'], 0.0);
    final hasUsefulGps = _isUsefulLatLng(lat, lon);

    FirebaseRepo.instance.upsertDailyUsageFromOdo(next).catchError((e) {
      debugPrint('[FleetProvider] Daily usage update error: $e');
    });

    if (!hasUsefulGps) return;

    final now = DateTime.now();
    final lastWrite = _lastHistoryWriteAt[next.id];
    if (lastWrite != null && now.difference(lastWrite) < _historyWriteInterval) {
      return;
    }
    _lastHistoryWriteAt[next.id] = now;

    FirebaseRepo.instance
        .upsertHistoryRoutePointFromVehicle(
          next,
          staleAfter: _historyCloseAfter,
          minPointInterval: _historyWriteInterval,
        )
        .catchError((e) {
      debugPrint('[FleetProvider] History route update error: $e');
    });
  }

  Future<void> _closeStaleHistoryRoutes() async {
    if (_isClosingStaleHistoryRoutes || _vehicles.isEmpty) return;
    _isClosingStaleHistoryRoutes = true;

    try {
      final ids = _vehicles.map((v) => v.id).toList(growable: false);
      for (final id in ids) {
        await FirebaseRepo.instance.closeStaleHistoryRoutes(
          id,
          staleAfter: _historyCloseAfter,
        );
      }
    } catch (e) {
      debugPrint('[FleetProvider] Close stale history routes error: $e');
    } finally {
      _isClosingStaleHistoryRoutes = false;
    }
  }

  bool _isUsefulLatLng(double lat, double lon) {
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    if (lat.abs() < 0.000001 && lon.abs() < 0.000001) return false;
    return true;
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  bool _toBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    final s = '$value'.toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  @override
  void dispose() {
    _historyCloseTimer?.cancel();
    _vehiclesSub?.cancel();
    _mqttSub?.cancel();
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */