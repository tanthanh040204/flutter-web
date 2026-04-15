import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle.dart';
import '../services/firebase_repo.dart';
import '../services/mqtt_service.dart';

class FleetProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = [];

  StreamSubscription<List<Vehicle>>? _vehiclesSub;
  MqttService? _mqttService;
  StreamSubscription<MqttVehicleState>? _mqttSub;

  int _selectedIndex = 0;
  bool _isSyncing = false;
  bool _isAddingVehicle = false;
  String? _lastError;

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
      throw StateError('Chưa có xe nào trong danh sách.');
    }
    return value;
  }

  double? get selectedTemp => selectedOrNull?.temp;
  double? get selectedHum => selectedOrNull?.hum;
  double? get selectedDust => selectedOrNull?.dust;

  void selectVehicle(int index) {
    if (index < 0 || index >= _vehicles.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> addVehicle({
    required String name,
    int batteryPercent = 80,
    double totalKm = 0,
    LatLng? lastLocation,
  }) async {
    if (_isAddingVehicle) return;

    _isAddingVehicle = true;
    _lastError = null;
    notifyListeners();

    try {
      final newId = await FirebaseRepo.instance.createVehicle(
        name: name,
        batteryPercent: batteryPercent,
        totalKm: totalKm,
        lastLocation: lastLocation,
      );

      final newIndex = _vehicles.indexWhere((v) => v.id == newId);
      if (newIndex >= 0) {
        _selectedIndex = newIndex;
      }
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isAddingVehicle = false;
      notifyListeners();
    }
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
      totalKm: _toDouble(data['totalKm'], current.totalKm),
      lastLocation: LatLng(
        _toDouble(data['lat'], current.lastLocation.latitude),
        _toDouble(data['lon'], current.lastLocation.longitude),
      ),
      updatedAt: DateTime.now(),
    );

    _vehicles[index] = next;
    notifyListeners();
  }

  Future<void> sendSetLock(bool locked) async {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    await mqtt.publishCommand(current.id, {
      'action': locked ? 'lock' : 'unlock',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendSetRunning(bool running) async {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    await mqtt.publishCommand(current.id, {
      'action': running ? 'start' : 'stop',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> requestHorn() async {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    await mqtt.publishCommand(current.id, {
      'action': 'horn',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> requestFindVehicle() async {
    final current = selectedOrNull;
    final mqtt = _mqttService;
    if (current == null || mqtt == null) return;

    await mqtt.publishCommand(current.id, {
      'action': 'find_vehicle',
      'source': 'flutter_app',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
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
    _vehiclesSub?.cancel();
    _mqttSub?.cancel();
    super.dispose();
  }
}
