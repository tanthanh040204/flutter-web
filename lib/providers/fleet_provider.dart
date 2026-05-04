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
  StreamSubscription<MqttNotiMessage>? _notiSub;

  // Last seen totalKm per vehicle — used to compute delta for maintenance
  final Map<String, double> _lastSeenTotalKm = {};

  // Vehicles awaiting OK ack for CLEAR_TOTAL_DISTANCE
  final Set<String> _pendingClearTotal = {};

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
    _notiSub?.cancel();

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

    _notiSub = service.notifications.listen(_onNoti);
  }

  // Broadcast CLEAR_TOTAL_DISTANCE to every vehicle's /cmd topic. Each device
  // is added to a pending set; when the device replies "OK" on /noti, that
  // vehicle's totalKm is reset to 0 (see _onNoti).
  bool clearTotalDistance() {
    final mqtt = _mqttService;
    if (mqtt == null || _vehicles.isEmpty) return false;

    var sent = false;
    for (final v in _vehicles) {
      if (mqtt.publish(v.id, 'CLEAR_TOTAL_DISTANCE')) {
        _pendingClearTotal.add(v.id);
        sent = true;
      }
    }
    if (sent) notifyListeners();
    return sent;
  }

  void _onNoti(MqttNotiMessage msg) {
    final token = msg.message.trim().toUpperCase();
    if (token != 'OK') return;
    if (!_pendingClearTotal.remove(msg.deviceId)) return;

    final index = _vehicles.indexWhere((v) => v.id == msg.deviceId);
    if (index < 0) return;

    _lastSeenTotalKm[msg.deviceId] = 0;
    final reset = _vehicles[index].copyWith(
      totalKm: 0,
      updatedAt: DateTime.now(),
    );
    _vehicles[index] = reset;
    notifyListeners();

    FirebaseRepo.instance.saveVehicle(reset).catchError((e) {
      debugPrint('[FleetProvider] saveVehicle after clear error: $e');
    });
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

    // ---- totalKm + maintenance accrual ----
    double nextTotalKm = current.totalKm;
    if (data.containsKey('totalKm')) {
      nextTotalKm = _toDouble(data['totalKm'], current.totalKm);

      // Seed baseline on first sighting; thereafter only positive deltas count.
      // A drop in totalKm means the device was reset (CLEAR_TOTAL_DISTANCE) —
      // re-seed without crediting maintenance.
      final last = _lastSeenTotalKm[id];
      if (last != null && nextTotalKm > last) {
        final deltaKm = nextTotalKm - last;
        FirebaseRepo.instance
            .incrementMaintenanceByDistance(id, deltaKm)
            .catchError((e) {
          debugPrint('[FleetProvider] incrementMaintenance error: $e');
        });
      }
      _lastSeenTotalKm[id] = nextTotalKm;
    }

    final next = current.copyWith(
      batteryPercent: _toInt(
        data['batteryPercent'],
        current.batteryPercent,
      ).clamp(0, 100).toInt(),
      isLocked: _toBool(data['isLocked'], current.isLocked),
      isRunning: _toBool(data['isRunning'], current.isRunning),
      totalKm: nextTotalKm,
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

    // Persist latest sensor/location data to Firebase for all devices
    FirebaseRepo.instance.saveVehicle(next).catchError((e) {
      debugPrint('[FleetProvider] Firebase save error: $e');
    });
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
    _notiSub?.cancel();
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */