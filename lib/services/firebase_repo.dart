// @file       firebase_repo.dart
// @brief      Service for Firebase Repo.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';

import '../config/feature_config.dart';
import '../models/app_note.dart';
import '../models/app_notification.dart';
import '../models/employee_account.dart';
import '../models/daily_stat.dart';
import '../models/history_route.dart';
import '../models/maintenance_item.dart';
import '../models/parking_zone.dart';
import '../models/rental_user.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';

/* Public classes ----------------------------------------------------- */
class FirebaseRepo {
  FirebaseRepo._();
  static final FirebaseRepo instance = FirebaseRepo._();

  final Map<String, Vehicle> _localVehicles = <String, Vehicle>{};
  final StreamController<List<Vehicle>> _localVehiclesCtl =
      StreamController<List<Vehicle>>.broadcast();

  final Map<String, String> _localEmployeePasswords = <String, String>{
    '1001': '123456',
  };

  final List<AppNotificationItem> _localNotifications = <AppNotificationItem>[];
  final StreamController<List<AppNotificationItem>> _localNotificationsCtl =
      StreamController<List<AppNotificationItem>>.broadcast();

  final StreamController<List<EmployeeAccount>> _localEmployeeAccountsCtl =
      StreamController<List<EmployeeAccount>>.broadcast();

  final List<AppNote> _localNotes = <AppNote>[];
  final StreamController<List<AppNote>> _localNotesCtl =
      StreamController<List<AppNote>>.broadcast();

  bool get _isReady => Firebase.apps.isNotEmpty;

  bool get _shouldUseLocalMode {
    if (!_isReady) return true;
    try {
      final options = Firebase.app().options;
      return options.projectId.trim().toLowerCase() == 'demo-project';
    } catch (_) {
      return true;
    }
  }

  FirebaseFirestore? get _db {
    if (!_isReady || _shouldUseLocalMode) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _vehicles =>
      _db?.collection('vehicles');

  CollectionReference<Map<String, dynamic>>? get _employeeAccounts =>
      _db?.collection('employee_accounts');

  CollectionReference<Map<String, dynamic>>? get _appNotifications =>
      _db?.collection('app_notifications');

  CollectionReference<Map<String, dynamic>>? get _appNotes =>
      _db?.collection('app_notes');

  CollectionReference<Map<String, dynamic>>? get _parkingZones =>
      _db?.collection('parking_zones');

  CollectionReference<Map<String, dynamic>>? get _rentalUsers =>
      _db?.collection('rental_users');

  // ---- Parking zones (shared by web admin + mobile app) ----------------
  Future<void> _ensureSeedParkingZones() async {
    final zones = _parkingZones;
    if (zones == null) return;

    final snap = await zones.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    for (final zone in ParkingZone.defaultSeed) {
      await zones.doc(zone.id).set({
        ...zone.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<ParkingZone>> watchParkingZones() {
    final zones = _parkingZones;
    if (zones == null) {
      return Stream.value(List<ParkingZone>.from(ParkingZone.defaultSeed));
    }

    Future.microtask(_ensureSeedParkingZones);

    return zones.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => ParkingZone.fromMap(doc.id, doc.data()))
          .where((z) => z.isActive)
          .toList();
      list.sort((a, b) => a.id.compareTo(b.id));
      return list;
    });
  }

  Future<void> upsertParkingZone(ParkingZone zone) async {
    final zones = _parkingZones;
    if (zones == null) return;
    await zones.doc(zone.id).set({
      ...zone.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteParkingZone(String zoneId) async {
    final zones = _parkingZones;
    if (zones == null) return;
    await zones.doc(zoneId).delete();
  }

  // ---- Rental users (shared by web admin + mobile app) -----------------
  Future<void> _ensureSeedRentalUsers() async {
    final users = _rentalUsers;
    if (users == null) return;

    final snap = await users.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    for (final user in RentalUser.defaultSeed) {
      await users.doc(user.userId).set({
        ...user.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<RentalUser>> watchRentalUsers() {
    final users = _rentalUsers;
    if (users == null) {
      return Stream.value(List<RentalUser>.from(RentalUser.defaultSeed));
    }

    Future.microtask(_ensureSeedRentalUsers);

    return users.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => RentalUser.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.userId.compareTo(b.userId));
      return list;
    });
  }

  Future<void> upsertRentalUser(RentalUser user) async {
    final users = _rentalUsers;
    if (users == null) return;
    await users.doc(user.userId).set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setRentalUserTokens(String userId, int tokens) async {
    final users = _rentalUsers;
    if (users == null) return;
    await users.doc(userId).set({
      'userId': userId,
      'tokens': tokens < 0 ? 0 : tokens,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setRentalUserState({
    required String userId,
    required int tokens,
    required int debt,
    required DateTime? debtStartedAt,
    required bool isLocked,
  }) async {
    final users = _rentalUsers;
    if (users == null) return;
    await users.doc(userId).set({
      'userId': userId,
      'tokens': tokens < 0 ? 0 : tokens,
      'debt': debt < 0 ? 0 : debt,
      'debtStartedAt':
          debtStartedAt == null ? null : Timestamp.fromDate(debtStartedAt),
      'isLocked': isLocked,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteRentalUser(String userId) async {
    final users = _rentalUsers;
    if (users == null) return;
    await users.doc(userId).delete();
  }

  List<Vehicle> _sortedLocalVehicles() {
    final list = _localVehicles.values.toList();
    list.sort((a, b) => _vehicleSortKey(a.id).compareTo(_vehicleSortKey(b.id)));
    return list;
  }

  void _emitLocalVehicles() {
    if (_localVehiclesCtl.isClosed) return;
    _localVehiclesCtl.add(_sortedLocalVehicles());
  }

  List<AppNotificationItem> _sortedLocalNotifications({int limit = 50}) {
    final list = List<AppNotificationItem>.from(_localNotifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  void _emitLocalNotifications({int limit = 50}) {
    if (_localNotificationsCtl.isClosed) return;
    _localNotificationsCtl.add(_sortedLocalNotifications(limit: limit));
  }

  List<EmployeeAccount> _sortedLocalEmployeeAccounts() {
    final list = _localEmployeePasswords.entries
        .map(
          (entry) => EmployeeAccount(
            employeeCode: entry.key,
            password: entry.value,
            updatedAt: DateTime.now(),
          ),
        )
        .toList();
    list.sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
    return list;
  }

  void _emitLocalEmployeeAccounts() {
    if (_localEmployeeAccountsCtl.isClosed) return;
    _localEmployeeAccountsCtl.add(_sortedLocalEmployeeAccounts());
  }

  List<AppNote> _sortedLocalNotes() {
    final list = List<AppNote>.from(_localNotes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void _emitLocalNotes() {
    if (_localNotesCtl.isClosed) return;
    _localNotesCtl.add(_sortedLocalNotes());
  }

  Future<void> _ensureSeedEmployeeAccount() async {
    final employees = _employeeAccounts;
    if (employees == null) return;

    final snap = await employees.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    await employees.doc('1001').set({
      'employeeCode': '1001',
      'password': '123456',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> verifyEmployeeLogin({
    required String employeeCode,
    required String password,
  }) async {
    final code = employeeCode.trim();
    final pass = password.trim();
    if (code.isEmpty || pass.isEmpty) return false;

    final employees = _employeeAccounts;
    if (employees == null) {
      return (_localEmployeePasswords[code] ?? '') == pass;
    }

    await _ensureSeedEmployeeAccount();

    final snap = await employees.doc(code).get();
    if (!snap.exists) return false;

    final data = snap.data() ?? <String, dynamic>{};
    final savedPassword = _asString(data['password']) ?? '';
    return savedPassword == pass;
  }

  Future<bool> changeEmployeePassword({
    required String employeeCode,
    required String currentPassword,
    required String newPassword,
  }) async {
    final code = employeeCode.trim();
    final current = currentPassword.trim();
    final next = newPassword.trim();

    if (code.isEmpty || current.isEmpty || next.isEmpty) return false;

    final employees = _employeeAccounts;
    if (employees == null) {
      if ((_localEmployeePasswords[code] ?? '') != current) {
        return false;
      }
      _localEmployeePasswords[code] = next;
      _emitLocalEmployeeAccounts();
      return true;
    }

    await _ensureSeedEmployeeAccount();

    final ref = employees.doc(code);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data() ?? <String, dynamic>{};
    final savedPassword = _asString(data['password']) ?? '';
    if (savedPassword != current) return false;

    await ref.set({
      'employeeCode': code,
      'password': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Stream<List<EmployeeAccount>> watchEmployeeAccounts() {
    final employees = _employeeAccounts;
    if (employees == null) {
      Future.microtask(_emitLocalEmployeeAccounts);
      return _localEmployeeAccountsCtl.stream;
    }

    Future.microtask(_ensureSeedEmployeeAccount);

    return employees.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => EmployeeAccount.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
      return list;
    });
  }

  Future<bool> addEmployeeAccount({
    required String employeeCode,
    required String password,
  }) async {
    final code = employeeCode.trim();
    final pass = password.trim();
    if (code.isEmpty || pass.isEmpty) return false;

    final employees = _employeeAccounts;
    if (employees == null) {
      if (_localEmployeePasswords.containsKey(code)) return false;
      _localEmployeePasswords[code] = pass;
      _emitLocalEmployeeAccounts();
      return true;
    }

    await _ensureSeedEmployeeAccount();

    final ref = employees.doc(code);
    final existing = await ref.get();
    if (existing.exists) return false;

    await ref.set({
      'employeeCode': code,
      'password': pass,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<bool> deleteEmployeeAccount(String employeeCode) async {
    final code = employeeCode.trim();
    if (code.isEmpty) return false;

    final employees = _employeeAccounts;
    if (employees == null) {
      final removed = _localEmployeePasswords.remove(code) != null;
      if (removed) _emitLocalEmployeeAccounts();
      return removed;
    }

    final ref = employees.doc(code);
    final snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  Future<void> addLoginNotification(String employeeCode) async {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final message =
        'Employee code $employeeCode has logged in at $hour:$minute';

    final notifications = _appNotifications;
    if (notifications == null) {
      _localNotifications.insert(
        0,
        AppNotificationItem(
          id: 'local_${now.microsecondsSinceEpoch}',
          message: message,
          type: 'login',
          employeeCode: employeeCode,
          createdAt: now,
        ),
      );
      _emitLocalNotifications();
      return;
    }

    await notifications.add({
      'message': message,
      'type': 'login',
      'employeeCode': employeeCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotificationItem>> watchAppNotifications({int limit = 50}) {
    final notifications = _appNotifications;
    if (notifications == null) {
      Future.microtask(() => _emitLocalNotifications(limit: limit));
      return _localNotificationsCtl.stream.map((items) {
        if (items.length <= limit) return items;
        return items.take(limit).toList();
      });
    }

    return notifications
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => AppNotificationItem.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> deleteAppNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    final notifications = _appNotifications;
    if (notifications == null) {
      _localNotifications.removeWhere((item) => item.id == id);
      _emitLocalNotifications();
      return;
    }

    await notifications.doc(id).delete();
  }

  Stream<List<AppNote>> watchNotes() {
    final notes = _appNotes;
    if (notes == null) {
      Future.microtask(_emitLocalNotes);
      return _localNotesCtl.stream;
    }

    return notes.orderBy('updatedAt', descending: true).snapshots().map((snap) {
      return snap.docs
          .map((doc) => AppNote.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> createNote({
    required String title,
    required String content,
  }) async {
    final safeTitle = title.trim();
    final safeContent = content.trim();
    if (safeContent.isEmpty) return;

    final now = DateTime.now();
    final notes = _appNotes;
    if (notes == null) {
      _localNotes.insert(
        0,
        AppNote(
          id: 'note_${now.microsecondsSinceEpoch}',
          title: safeTitle,
          content: safeContent,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _emitLocalNotes();
      return;
    }

    await notes.add({
      'title': safeTitle,
      'content': safeContent,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNote({
    required String noteId,
    required String title,
    required String content,
  }) async {
    final id = noteId.trim();
    final safeTitle = title.trim();
    final safeContent = content.trim();
    if (id.isEmpty || safeContent.isEmpty) return;

    final notes = _appNotes;
    if (notes == null) {
      final index = _localNotes.indexWhere((item) => item.id == id);
      if (index < 0) return;
      final current = _localNotes[index];
      _localNotes[index] = AppNote(
        id: current.id,
        title: safeTitle,
        content: safeContent,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _emitLocalNotes();
      return;
    }

    await notes.doc(id).set({
      'title': safeTitle,
      'content': safeContent,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteNote(String noteId) async {
    final id = noteId.trim();
    if (id.isEmpty) return;

    final notes = _appNotes;
    if (notes == null) {
      _localNotes.removeWhere((item) => item.id == id);
      _emitLocalNotes();
      return;
    }

    await notes.doc(id).delete();
  }

  Future<void> deleteHistoryRoute(String vehicleId, String routeId) async {
    final vehicles = _vehicles;
    if (vehicles == null) {
      throw StateError('Firestore has not been initialized.');
    }

    await vehicles
        .doc(vehicleId)
        .collection('history_routes')
        .doc(routeId)
        .delete();
  }

  Future<void> saveVehicle(Vehicle v) async {
    final vehicles = _vehicles;
    if (vehicles == null) {
      _localVehicles[v.id] = v;
      _emitLocalVehicles();
      return;
    }

    try {
      await vehicles.doc(v.id).set({
        'id': v.id,
        'name': v.name,
        'batteryPercent': v.batteryPercent,
        'isLocked': v.isLocked,
        'isRunning': v.isRunning,
        'totalKm': v.totalKm,
        'temp': v.temp,
        'hum': v.hum,
        'dust': v.dust,
        'velocityKmh': v.velocityKmh,
        'lastLocation': {
          'lat': v.lastLocation.latitude,
          'lon': v.lastLocation.longitude,
          'name': v.name,
          'totalKm': v.totalKm,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      _localVehicles[v.id] = v;
      _emitLocalVehicles();
    }
  }

  // Create a vehicle with an explicit ID (format: haq-trk-xxx).
  Future<String> createVehicle({
    required String vehicleId,
    int batteryPercent = 80,
    double totalKm = 0,
    LatLng? lastLocation,
  }) async {
    final safeId = vehicleId.trim();
    if (safeId.isEmpty) throw ArgumentError('vehicleId cannot be empty');

    final location = lastLocation ?? const LatLng(21.0287, 105.8522);

    await saveVehicle(
      Vehicle(
        id: safeId,
        name: safeId,
        batteryPercent: batteryPercent.clamp(0, 100).toInt(),
        isLocked: true,
        isRunning: false,
        totalKm: totalKm,
        temp: 0,
        hum: 0,
        dust: 0,
        velocityKmh: 0,
        lastLocation: location,
        updatedAt: DateTime.now(),
      ),
    );

    await ensureDefaultMaintenanceItems(safeId);
    return safeId;
  }

  // Delete a vehicle document and its sub-collections are pruned over time by TTL.
  Future<void> deleteVehicle(String vehicleId) async {
    final vehicles = _vehicles;
    if (vehicles == null) {
      _localVehicles.remove(vehicleId);
      _emitLocalVehicles();
      return;
    }
    await vehicles.doc(vehicleId).delete();
  }

  Stream<List<Vehicle>> watchVehicles() {
    final vehicles = _vehicles;
    if (vehicles == null) {
      Future.microtask(_emitLocalVehicles);
      return _localVehiclesCtl.stream;
    }

    return vehicles.snapshots().map((snap) {
      final list = snap.docs.map((d) => _vehicleFromDoc(d)).toList();
      list.sort(
        (a, b) => _vehicleSortKey(a.id).compareTo(_vehicleSortKey(b.id)),
      );
      return list;
    });
  }

  Stream<List<DailyStat>> watchDailyUsage(String vehicleId) {
    final vehicles = _vehicles;
    if (vehicles == null) {
      return const Stream<List<DailyStat>>.empty();
    }

    return vehicles
        .doc(vehicleId)
        .collection('daily_usage')
        .orderBy('dayStart')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final ts = data['dayStart'] as Timestamp?;
            final day = ts?.toDate().toLocal() ?? _parseDailyUsageDocId(doc.id);

            return DailyStat(
              day: DateTime(day.year, day.month, day.day),
              distanceKm: ((data['distanceKm'] ?? 0) as num).toDouble(),
              avgSpeedKmh: 0,
              maxSpeedKmh: 0,
            );
          }).toList();
        });
  }

  Stream<List<HistoryRouteRecord>> watchHistoryRoutes(
    String vehicleId, {
    int keepDays = FeatureConfig.historyKeepDays,
  }) {
    final vehicles = _vehicles;
    if (vehicles == null) {
      return const Stream<List<HistoryRouteRecord>>.empty();
    }

    final keepFrom = DateTime.now().subtract(Duration(days: keepDays - 1));

    return vehicles
        .doc(vehicleId)
        .collection('history_routes')
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(keepFrom))
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final m = doc.data();

            final rawPoints = (m['points'] as List?) ?? const [];
            final points = rawPoints.map((e) {
              final p = Map<String, dynamic>.from(e as Map);
              return LatLng(
                ((p['lat'] ?? 0) as num).toDouble(),
                ((p['lon'] ?? 0) as num).toDouble(),
              );
            }).toList();

            return HistoryRouteRecord(
              id: doc.id,
              vehicleId: (m['vehicleId'] ?? vehicleId).toString(),
              dayKey: (m['dayKey'] ?? '').toString(),
              startAt: (m['startAt'] as Timestamp).toDate(),
              endAt: m['endAt'] == null
                  ? null
                  : (m['endAt'] as Timestamp).toDate(),
              isClosed: (m['isClosed'] ?? false) as bool,
              startTotalKm: ((m['startTotalKm'] ?? 0) as num).toDouble(),
              endTotalKm: ((m['endTotalKm'] ?? 0) as num).toDouble(),
              distanceKm: ((m['distanceKm'] ?? 0) as num).toDouble(),
              points: points,
            );
          }).toList();
        });
  }

  Future<void> upsertDailyUsageFromOdo(
    Vehicle vehicle, {
    int keepDays = FeatureConfig.historyKeepDays,
  }) async {
    final db = _db;
    final vehicles = _vehicles;

    if (db == null || vehicles == null) return;

    final localTime = vehicle.updatedAt.toLocal();
    final dayStart = DateTime(localTime.year, localTime.month, localTime.day);
    final dayKey = _dailyUsageDocId(dayStart);

    final docRef = vehicles
        .doc(vehicle.id)
        .collection('daily_usage')
        .doc(dayKey);

    await db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final currentOdo = vehicle.totalKm;
      final expiresAt = dayStart.add(Duration(days: keepDays));

      if (!snap.exists) {
        tx.set(docRef, {
          'dayKey': dayKey,
          'dayStart': Timestamp.fromDate(dayStart),
          'startTotalKm': currentOdo,
          'endTotalKm': currentOdo,
          'distanceKm': 0.0,
          'lastSeenAt': Timestamp.fromDate(localTime),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};
      final startKm = ((data['startTotalKm'] ?? currentOdo) as num).toDouble();
      final oldEndKm = ((data['endTotalKm'] ?? startKm) as num).toDouble();

      final nextEndKm = currentOdo > oldEndKm ? currentOdo : oldEndKm;
      final distanceKm = nextEndKm - startKm;

      tx.update(docRef, {
        'endTotalKm': nextEndKm,
        'distanceKm': distanceKm < 0 ? 0.0 : distanceKm,
        'lastSeenAt': Timestamp.fromDate(localTime),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    });

    await pruneOldDailyUsage(vehicle.id, keepDays: keepDays);
  }

  Future<void> pruneOldDailyUsage(
    String vehicleId, {
    int keepDays = FeatureConfig.historyKeepDays,
  }) async {
    final db = _db;
    final vehicles = _vehicles;

    if (db == null || vehicles == null) return;

    final now = DateTime.now().toLocal();
    final keepFrom = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: keepDays - 1));

    final query = await vehicles
        .doc(vehicleId)
        .collection('daily_usage')
        .where('dayStart', isLessThan: Timestamp.fromDate(keepFrom))
        .get();

    if (query.docs.isEmpty) return;

    final batch = db.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  String _dailyUsageDocId(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _parseDailyUsageDocId(String id) {
    final parts = id.split('-');
    if (parts.length != 3) return DateTime.now();

    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }

  Vehicle _vehicleFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final rawLastLocation = m['lastLocation'];
    final Map<String, dynamic> loc = rawLastLocation is Map<String, dynamic>
        ? rawLastLocation
        : <String, dynamic>{};

    final vehicleName = _asString(m['name']) ?? _asString(loc['name']) ?? d.id;
    final totalKm = _asDouble(m['totalKm']) ?? _asDouble(loc['totalKm']) ?? 0.0;
    final batteryPercent = _asInt(m['batteryPercent']) ?? 0;
    final isLocked = _asBool(m['isLocked']) ?? true;
    final isRunning = _asBool(m['isRunning']) ?? false;
    final lat = _asDouble(loc['lat']) ?? _asDouble(m['lat']) ?? 0.0;
    final lon = _asDouble(loc['lon']) ?? _asDouble(m['lon']) ?? 0.0;

    final rawUpdatedAt = m['updatedAt'];
    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : DateTime.now();

    return Vehicle(
      id: d.id,
      name: vehicleName,
      batteryPercent: batteryPercent.clamp(0, 100).toInt(),
      isLocked: isLocked,
      isRunning: isRunning,
      totalKm: totalKm,
      temp: _asDouble(m['temp']) ?? 0.0,
      hum: _asDouble(m['hum']) ?? 0.0,
      dust: _asDouble(m['dust']) ?? 0.0,
      velocityKmh: _asDouble(m['velocityKmh']) ?? 0.0,
      lastLocation: LatLng(lat, lon),
      updatedAt: updatedAt,
    );
  }

  int _vehicleSortKey(String id) {
    final s = id.trim();
    // haq-trk-001 format
    final matchNew = RegExp(r'^haq-trk-(\d+)$').firstMatch(s);
    if (matchNew != null)
      return int.tryParse(matchNew.group(1) ?? '') ?? (1 << 30);
    // Legacy V1/V2 format
    final matchOld = RegExp(r'^(?:V|v)(\d+)$').firstMatch(s);
    if (matchOld != null)
      return int.tryParse(matchOld.group(1) ?? '') ?? (1 << 30);
    return 1 << 30;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  Stream<List<MaintenanceItem>> watchMaintenance(String vehicleId) {
    final vehicles = _vehicles;
    if (vehicles == null) return const Stream<List<MaintenanceItem>>.empty();

    return vehicles
        .doc(vehicleId)
        .collection('maintenance')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MaintenanceItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> saveMaintenanceItem(String vehicleId, MaintenanceItem it) async {
    final vehicles = _vehicles;
    if (vehicles == null) return;

    await vehicles.doc(vehicleId).collection('maintenance').doc(it.id).set({
      'name': it.name,
      'maintanceKm': it.maintanceKm,
      'cycleKm': it.cycleKm,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureDefaultMaintenanceItems(String vehicleId) async {
    final db = _db;
    final vehicles = _vehicles;
    if (db == null || vehicles == null) return;

    final ref = vehicles.doc(vehicleId).collection('maintenance');
    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = db.batch();
    for (final item in MaintenanceItem.defaultSeed) {
      batch.set(ref.doc(item.id), {
        'name': item.name,
        'maintanceKm': item.maintanceKm,
        'cycleKm': item.cycleKm,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> incrementMaintenanceByDistance(
    String vehicleId,
    double deltaKm,
  ) async {
    if (deltaKm <= 0) return;

    final db = _db;
    final vehicles = _vehicles;
    if (db == null || vehicles == null) return;

    final ref = vehicles.doc(vehicleId).collection('maintenance');
    final snap = await ref.get();
    if (snap.docs.isEmpty) return;

    final batch = db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      final current =
          _asDouble(data['maintanceKm']) ??
          _asDouble(data['maintenanceKm']) ??
          0.0;

      batch.set(doc.reference, {
        'maintanceKm': current + deltaKm,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Stream<List<Trip>> watchTrips(String vehicleId) {
    final vehicles = _vehicles;
    if (vehicles == null) return const Stream<List<Trip>>.empty();

    return vehicles.doc(vehicleId).collection('trips').snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = d.data();
        final pts = (m['points'] as List<dynamic>? ?? [])
            .map(
              (p) => TripPoint(
                time:
                    DateTime.tryParse((p['time'] ?? '').toString()) ??
                    DateTime.now(),
                latLng: LatLng(
                  (p['lat'] ?? 0).toDouble(),
                  (p['lon'] ?? 0).toDouble(),
                ),
                speedKmh: (p['speedKmh'] ?? 0).toDouble(),
              ),
            )
            .toList();
        return Trip(
          id: d.id,
          vehicleId: vehicleId,
          startTime:
              DateTime.tryParse((m['startTime'] ?? '').toString()) ??
              DateTime.now(),
          endTime:
              DateTime.tryParse((m['endTime'] ?? '').toString()) ??
              DateTime.now(),
          points: pts,
        );
      }).toList();
    });
  }

  Future<void> saveTrip(String vehicleId, Trip t) async {
    final vehicles = _vehicles;
    if (vehicles == null) return;

    await vehicles.doc(vehicleId).collection('trips').doc(t.id).set({
      'startTime': t.startTime.toIso8601String(),
      'endTime': t.endTime.toIso8601String(),
      'distanceKm': t.distanceKm,
      'maxSpeedKmh': t.maxSpeedKmh,
      'avgSpeedKmh': t.avgSpeedKmh,
      'points': t.points
          .map(
            (p) => {
              'time': p.time.toIso8601String(),
              'lat': p.latLng.latitude,
              'lon': p.latLng.longitude,
              'speedKmh': p.speedKmh,
            },
          )
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/* End of file -------------------------------------------------------- */
