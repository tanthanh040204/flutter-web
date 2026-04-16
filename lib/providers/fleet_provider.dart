import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle.dart';
import '../services/firebase_repo.dart';
import '../services/mqtt_service.dart';

class FleetProvider extends ChangeNotifier {
  final List<Vehicle> _vehicles = [];

  StreamSubscription<List<Vehicle>>? _vehiclesSub;
  


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

}