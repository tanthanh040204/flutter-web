import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/maintenance_item.dart';
import '../models/vehicle.dart';
import '../services/firebase_repo.dart';

class MaintenanceProvider extends ChangeNotifier {
  final Map<String, List<MaintenanceItem>> _byVehicle = {};
  final Map<String, StreamSubscription<List<MaintenanceItem>>> _subs = {};
  final Set<String> _creatingDefaults = {};

  List<MaintenanceItem> itemsOf(String vehicleId) =>
      List.unmodifiable(_byVehicle[vehicleId] ?? const []);

  void bindVehicles(List<Vehicle> vehicles) {
    final wanted = vehicles.map((e) => e.id).toSet();

    final removed = _subs.keys.where((id) => !wanted.contains(id)).toList();
    for (final id in removed) {
      _subs.remove(id)?.cancel();
      _byVehicle.remove(id);
    }

    for (final vehicle in vehicles) {
      if (!_byVehicle.containsKey(vehicle.id)) {
        ensureDefaults(vehicle.id);
      }

      if (_subs.containsKey(vehicle.id)) continue;

      _subs[vehicle.id] = FirebaseRepo.instance.watchMaintenance(vehicle.id).listen(
        (items) async {
          if (items.isEmpty) {
            await ensureDefaults(vehicle.id);
            return;
          }
          _byVehicle[vehicle.id] = items;
          notifyListeners();
        },
        onError: (_) async {
          if (!_byVehicle.containsKey(vehicle.id)) {
            await ensureDefaults(vehicle.id);
          }
        },
      );
    }

    notifyListeners();
  }

  Future<void> ensureDefaults(String vehicleId) async {
    if (_creatingDefaults.contains(vehicleId)) return;
    if ((_byVehicle[vehicleId] ?? const []).isNotEmpty) return;

    _creatingDefaults.add(vehicleId);
    try {
      final defaults = <MaintenanceItem>[
        const MaintenanceItem(
          id: 'oil',
          name: 'Thay nhớt',
          maintanceKm: 0,
          cycleKm: 2000,
        ),
        const MaintenanceItem(
          id: 'brake',
          name: 'Tra/Thay nhớt thắng',
          maintanceKm: 0,
          cycleKm: 4000,
        ),
        const MaintenanceItem(
          id: 'battery',
          name: 'Kiểm tra/Thay pin',
          maintanceKm: 0,
          cycleKm: 12000,
        ),
      ];

      _byVehicle[vehicleId] = defaults;
      notifyListeners();

      await FirebaseRepo.instance.ensureDefaultMaintenanceItems(vehicleId);
    } finally {
      _creatingDefaults.remove(vehicleId);
    }
  }

  Future<void> addItem(
    String vehicleId, {
    required String name,
    required double cycleKm,
  }) async {
    final list = List<MaintenanceItem>.from(_byVehicle[vehicleId] ?? const []);
    final id = 'm${list.length + 1}_${DateTime.now().millisecondsSinceEpoch}';

    final newItem = MaintenanceItem(
      id: id,
      name: name,
      maintanceKm: 0,
      cycleKm: cycleKm,
    );

    list.add(newItem);
    _byVehicle[vehicleId] = list;
    notifyListeners();

    await FirebaseRepo.instance.saveMaintenanceItem(vehicleId, newItem);
  }

  Future<void> updateCycleKm(
    String vehicleId,
    String itemId,
    double cycleKm,
  ) async {
    final list = List<MaintenanceItem>.from(_byVehicle[vehicleId] ?? const []);
    final idx = list.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(cycleKm: cycleKm);
    _byVehicle[vehicleId] = list;
    notifyListeners();

    await FirebaseRepo.instance.saveMaintenanceItem(vehicleId, list[idx]);
  }

  Future<void> markServiced(String vehicleId, String itemId) async {
    final list = List<MaintenanceItem>.from(_byVehicle[vehicleId] ?? const []);
    final idx = list.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(maintanceKm: 0);
    _byVehicle[vehicleId] = list;
    notifyListeners();

    await FirebaseRepo.instance.saveMaintenanceItem(vehicleId, list[idx]);
  }

  List<String> dueMessagesForVehicle(Vehicle v) {
    final list = _byVehicle[v.id] ?? const <MaintenanceItem>[];
    final msgs = <String>[];

    for (final it in list) {
      if (it.isDue) {
        msgs.add('Đã đến lúc bảo dưỡng cho "${it.name}"');
      }
    }
    return msgs;
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
