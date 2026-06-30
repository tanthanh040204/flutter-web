// @file       rental_provider.dart
// @brief      Manages registered rental user IDs, active rentals, and token balances.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/feature_config.dart';
import '../models/device_data.dart';
import '../models/history_route.dart';
import '../models/parking_zone.dart';
import '../models/rental_user.dart';
import '../services/firebase_repo.dart';
import 'device_provider.dart';
import '../services/mqtt_service.dart';

/* Public types ------------------------------------------------------- */
class ActiveRental {
  const ActiveRental({
    required this.bikeId,
    required this.userId,
    required this.startTime,
    this.chargedTokens = 0,
  });

  final String bikeId;
  final String userId;
  final DateTime startTime;
  // Total tokens deducted so far (used directly as the bill amount)
  final int chargedTokens;

  ActiveRental withChargedTokens(int n) => ActiveRental(
    bikeId: bikeId,
    userId: userId,
    startTime: startTime,
    chargedTokens: n,
  );
}

/* Public classes ----------------------------------------------------- */
class RentalProvider extends ChangeNotifier {
  // Parking zones freom Firestore.
  final List<ParkingZone> _zones = List<ParkingZone>.from(
    ParkingZone.defaultSeed,
  );

  // Full rental-user list from Firestore (for the user management tab).
  List<RentalUser> _allUsers = List<RentalUser>.from(RentalUser.defaultSeed);

  // User tokens from Firestore.
  final Map<String, int> _userTokens = {
    for (final u in RentalUser.defaultSeed) u.userId: u.tokens,
  };
  // Per-user debt accounting. Mirrored from Firestore alongside tokens.
  final Map<String, int> _userDebt = {};
  final Map<String, DateTime> _debtStartedAt = {};
  final Set<String> _lockedUsers = {};

  StreamSubscription<List<ParkingZone>>? _zonesSub;
  StreamSubscription<List<RentalUser>>? _usersSub;

  // bikeId → 30-min block timer
  final Map<String, Timer> _blockTimers = {};
  // Block timer division remainder
  final Map<String, int> _blockHundredths = {};
  // bikeId → 15-min out-of-balance grace timer
  final Map<String, Timer> _graceTimers = {};
  // bikeId → position poll timer during grace period
  final Map<String, Timer> _graceCheckers = {};
  // bikeId → 1-hour pause timeout timer
  final Map<String, Timer> _pauseTimeoutTimers = {};

  // bikeId → active rental session
  final Map<String, ActiveRental> _activeRentals = {};

  // Bikes currently paused (50% rate applies)
  final Set<String> _pausedBikes = {};

  // Bikes currently in the middle of an async UNLOCK handshake
  final Set<String> _inProgressBikes = {};

  StreamSubscription<MqttRentalRequestMessage>? _rentalSub;
  StreamSubscription<MqttTokenRequestMessage>? _tokenSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  StreamSubscription<MqttDataMessage>? _dataSub;

  final Map<String, List<_RentalWindow>> _completedWindows = {};
  MqttService? _mqtt;
  DeviceProvider? _deviceProvider;

  // ---- Session route history (web-side fallback when the bridge is off) ----
  // GPS points / odometer accumulated for each in-progress rental.
  final Map<String, List<LatLng>> _rentalPoints = {};
  final Map<String, double> _rentalStartKm = {};
  final Map<String, double> _rentalLastKm = {};
  // Last device `distance_m` (meters) seen during the rental — used as the
  // authoritative trip distance when finalizing the session route.
  final Map<String, double> _rentalLastDistanceM = {};
  // Completed routes keyed by bikeId. Persisted locally (survives reload) and
  // best-effort to Firestore — saved in parallel.
  final Map<String, List<HistoryRouteRecord>> _sessionRoutes = {};

  static const String _kSessionRoutesKey = 'session_routes_v1';
  static const int _kSessionRoutesKeepDays = 30;

  RentalProvider() {
    _restoreSessionRoutes();
  }

  // Session routes for a vehicle, newest first (shown in the History tab).
  List<HistoryRouteRecord> sessionRoutesForVehicle(String vehicleId) {
    final list = _sessionRoutes[vehicleId];
    if (list == null || list.isEmpty) return const <HistoryRouteRecord>[];
    return List.unmodifiable(list.reversed.toList());
  }

  // Permanently drop locally-stored session routes by id (in-memory + persisted
  // copy). Returns true if any matched. No-op for ids not held locally — those
  // live only in Firestore and are removed via FirebaseRepo.
  bool deleteSessionRoutes(String vehicleId, Iterable<String> ids) {
    final list = _sessionRoutes[vehicleId];
    if (list == null || list.isEmpty) return false;
    final idSet = ids.toSet();
    final before = list.length;
    list.removeWhere((r) => idSet.contains(r.id));
    if (list.length == before) return false;
    if (list.isEmpty) _sessionRoutes.remove(vehicleId);
    notifyListeners();
    unawaited(_persistSessionRoutes());
    return true;
  }

  // Drops session routes older than the keep window (in place).
  void _pruneOldSessionRoutes() {
    final keepFrom = DateTime.now().subtract(
      const Duration(days: _kSessionRoutesKeepDays),
    );
    _sessionRoutes.removeWhere((_, list) {
      list.removeWhere((r) => r.startAt.isBefore(keepFrom));
      return list.isEmpty;
    });
  }

  // Load persisted session routes from local storage on startup.
  Future<void> _restoreSessionRoutes() async {
    if (!FeatureConfig.saveTripLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionRoutesKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((bikeId, value) {
        final list = (value as List)
            .map(
              (e) => HistoryRouteRecord.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        if (list.isNotEmpty) _sessionRoutes[bikeId] = list;
      });
      _pruneOldSessionRoutes();
      notifyListeners();
    } catch (e) {
      debugPrint('[Rental] restore session routes failed: $e');
    }
  }

  // Persist current session routes to local storage.
  Future<void> _persistSessionRoutes() async {
    try {
      _pruneOldSessionRoutes();
      final prefs = await SharedPreferences.getInstance();
      final map = _sessionRoutes.map(
        (bikeId, list) =>
            MapEntry(bikeId, list.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(_kSessionRoutesKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[Rental] persist session routes failed: $e');
    }
  }

  String _toVietnamTime(DateTime value) {
    final vn = value.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    final year = vn.year.toString().padLeft(4, '0');
    return '$year/${two(vn.month)}/${two(vn.day)}-'
        '${two(vn.hour)}:${two(vn.minute)}:${two(vn.second)}';
  }

  // ISO-like timestamp in VN time (UTC+7) for device cmd payloads.
  String _toRentalTs(DateTime value) {
    final vn = value.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${vn.year.toString().padLeft(4, '0')}-${two(vn.month)}-${two(vn.day)}'
        'T${two(vn.hour)}:${two(vn.minute)}:${two(vn.second)}';
  }

  List<ActiveRental> get activeRentals =>
      List.unmodifiable(_activeRentals.values.toList());

  // All rental users (for the user management tab), sorted by userId.
  List<RentalUser> get rentalUsers => List.unmodifiable(_allUsers);

  // Delete a user from Firebase (rental_users + app-owned users profile).
  // The watchRentalUsers stream refreshes the list afterwards.
  Future<void> deleteUser(String userId) {
    return FirebaseRepo.instance.deleteRentalUserCompletely(userId);
  }

  // Add or update a user in local mode
  Future<void> upsertUser(RentalUser user) {
    return FirebaseRepo.instance.upsertRentalUser(user);
  }

  ActiveRental? activeRentalForBike(String bikeId) => _activeRentals[bikeId];
  bool isBikeRented(String bikeId) => _activeRentals.containsKey(bikeId);
  bool isBikePaused(String bikeId) => _pausedBikes.contains(bikeId);
  int tokensOf(String userId) => _userTokens[userId] ?? 0;
  int debtOf(String userId) => _userDebt[userId] ?? 0;
  bool isUserLocked(String userId) => _lockedUsers.contains(userId);

  void bindToMqtt(MqttService mqtt, DeviceProvider deviceProvider) {
    _mqtt = mqtt;
    _deviceProvider = deviceProvider;
    _rentalSub?.cancel();
    _rentalSub = mqtt.rentalRequests.listen(_onRentalRequest);
    _tokenSub?.cancel();
    _tokenSub = mqtt.tokenRequests.listen(_onTokenRequest);
    _notiSub?.cancel();
    _notiSub = mqtt.notifications.listen(_onNotiMessage);
    _dataSub?.cancel();
    _dataSub = mqtt.dataMessages.listen(_onDeviceData);
  }

  void bindToFirebase() {
    _zonesSub?.cancel();
    _zonesSub = FirebaseRepo.instance.watchParkingZones().listen(
      _onZonesUpdated,
    );
    _usersSub?.cancel();
    _usersSub = FirebaseRepo.instance.watchRentalUsers().listen(
      _onRentalUsersUpdated,
    );
  }

  void _onZonesUpdated(List<ParkingZone> zones) {
    if (zones.isEmpty) return;
    _zones
      ..clear()
      ..addAll(zones);
    debugPrint('[Rental] parking zones updated: ${zones.length}');
    notifyListeners();
  }

  void _onRentalUsersUpdated(List<RentalUser> users) {
    if (users.isEmpty) return;
    _allUsers = List<RentalUser>.from(users);
    _userTokens.clear();
    _userDebt.clear();
    _debtStartedAt.clear();
    _lockedUsers.clear();
    for (final u in users) {
      _userTokens[u.userId] = u.tokens;
      if (u.debt > 0) _userDebt[u.userId] = u.debt;
      if (u.debtStartedAt != null) {
        _debtStartedAt[u.userId] = u.debtStartedAt!;
      }
      if (u.isLocked) _lockedUsers.add(u.userId);
    }
    debugPrint('[Rental] rental users synced from Firestore: ${users.length}');
    notifyListeners();
  }

  void _persistUserState(String userId) {
    final tokens = _userTokens[userId] ?? 0;
    final debt = _userDebt[userId] ?? 0;
    final debtStartedAt = _debtStartedAt[userId];
    final isLocked = _lockedUsers.contains(userId);
    // Fire-and-forget; offline mode silently no-ops inside FirebaseRepo.
    unawaited(
      FirebaseRepo.instance.setRentalUserState(
        userId: userId,
        tokens: tokens,
        debt: debt,
        debtStartedAt: debtStartedAt,
        isLocked: isLocked,
      ),
    );
  }

  // ---- Token requests ------------------------------------------------

  void _onTokenRequest(MqttTokenRequestMessage msg) {
    final mqtt = _mqtt;

    if (msg.raw.startsWith('QUERY_BALANCE=')) {
      final userId = msg.raw.substring('QUERY_BALANCE='.length).trim();
      if (!_userTokens.containsKey(userId)) {
        mqtt?.publishRaw(
          '$userId/response',
          'RESP_ADD_TOKEN_ERROR=ERR_USER_NOT_FOUND',
        );
        debugPrint('[Token] QUERY_BALANCE ERR_USER_NOT_FOUND: $userId');
        return;
      }
      final balance = _userTokens[userId] ?? 0;
      final debt = _userDebt[userId] ?? 0;
      mqtt?.publishRaw('$userId/response', 'RESP_BALANCE=$balance,$debt');
      debugPrint(
        '[Token] QUERY_BALANCE → RESP_BALANCE=$balance,$debt userId=$userId',
      );
      return;
    }

    if (!msg.raw.startsWith('REQ_ADD_TOKEN=')) return;
    final parts = msg.raw.substring('REQ_ADD_TOKEN='.length).split(',');
    if (parts.length < 2) return;

    final userId = parts[0].trim();
    final amount = int.tryParse(parts[1].trim());

    if (amount == null || amount <= 0) {
      mqtt?.publishRaw(
        '$userId/response',
        'RESP_ADD_TOKEN_ERROR=ERR_INVALID_AMOUNT',
      );
      debugPrint('[Token] ERR_INVALID_AMOUNT: userId=$userId raw=${parts[1]}');
      return;
    }

    if (!_userTokens.containsKey(userId)) {
      mqtt?.publishRaw(
        '$userId/response',
        'RESP_ADD_TOKEN_ERROR=ERR_USER_NOT_FOUND',
      );
      debugPrint('[Token] ERR_USER_NOT_FOUND: $userId');
      return;
    }

    int balance = (_userTokens[userId] ?? 0) + amount;

    // Clear debt if enough tokens added
    final int debt = _userDebt[userId] ?? 0;
    if (debt > 0) {
      final int repay = math.min(debt, balance);
      final int remainingDebt = debt - repay;
      balance -= repay;
      if (remainingDebt == 0) {
        final bool wasLocked = _lockedUsers.contains(userId);
        _userDebt.remove(userId);
        _debtStartedAt.remove(userId);
        _lockedUsers.remove(userId);
        debugPrint('[Token] debt cleared → unlock userId=$userId');

        ActiveRental? rental;
        for (final r in _activeRentals.values) {
          if (r.userId == userId) {
            rental = r;
            break;
          }
        }
        if (rental != null) {
          final String bikeId = rental.bikeId;
          mqtt?.publishToApp(bikeId, 'DEBT_CLEAR');
          mqtt?.publish(bikeId, 'DEBT_CLEAR');
          debugPrint('[Rental] DEBT_CLEAR bikeId=$bikeId userId=$userId');
          if (wasLocked) {
            _startBlockTimer(bikeId, userId);
            debugPrint(
              '[Rental] Block timer resumed after unlock bikeId=$bikeId',
            );
          }
        }
      } else {
        _userDebt[userId] = remainingDebt;
        debugPrint(
          '[Token] partial debt repay userId=$userId paid=$repay remaining=$remainingDebt',
        );
      }
    }

    _userTokens[userId] = balance;
    _persistUserState(userId);
    notifyListeners();
    mqtt?.publishRaw('$userId/response', 'RESP_ADD_TOKEN_SUCCESS=$balance');
    debugPrint('[Token] +$amount → $userId (total: $balance)');
  }

  // ---- Rental requests (from app via bike_id/app_web) ----------------

  void _onRentalRequest(MqttRentalRequestMessage msg) {
    final raw = msg.raw;
    final bikeId = msg.bikeId;
    if (raw.startsWith('START_RENTAL=')) {
      _handleStartRental(bikeId, raw.substring('START_RENTAL='.length).trim());
    } else if (raw.startsWith('PAUSE=')) {
      _handleAppPause(bikeId, raw.substring('PAUSE='.length).trim());
    } else if (raw.startsWith('RESUME=')) {
      _handleResume(bikeId, raw.substring('RESUME='.length).trim());
    } else if (raw.startsWith('STOP_RENTAL=')) {
      _handleStop(bikeId, raw.substring('STOP_RENTAL='.length).trim());
    } else if (raw.startsWith('QUERY_STATUS=')) {
      _handleQueryStatus(bikeId, raw.substring('QUERY_STATUS='.length).trim());
    }
  }

  // ---- Resync: app asks whether its restored session is still active -----

  void _handleQueryStatus(String bikeId, String userId) {
    final rental = _activeRentals[bikeId];

    if (rental == null || rental.userId != userId) {
      _mqtt?.publishToApp(bikeId, 'NO_ACTIVE_RENTAL=$userId');
      debugPrint(
        '[Rental] QUERY_STATUS → NO_ACTIVE_RENTAL bikeId=$bikeId userId=$userId',
      );
    }
  }

  // ---- Noti from device (via bike_id/noti) ---------------------------

  void _onNotiMessage(MqttNotiMessage msg) {
    final token = msg.message.trim().toUpperCase();
    final bikeId = msg.deviceId;
    if (token == 'NOTI_PAUSE') {
      _handleDevicePause(bikeId);
    } else if (token == 'STOP_RENTAL') {
      final rental = _activeRentals[bikeId];
      if (rental != null) _handleStop(bikeId, rental.userId);
    }
  }

  // ---- Stop rental (user-initiated, checks GPS) ----------------------

  Future<void> _handleStop(String bikeId, String userId) async {
    final mqtt = _mqtt;
    if (mqtt == null) return;

    final rental = _activeRentals[bikeId];
    if (rental == null || rental.userId != userId) {
      mqtt.publishToApp(bikeId, 'STOP_RENTAL_FAIL=$userId');
      return;
    }

    if (_isInValidParkingArea(bikeId)) {
      mqtt.publish(bikeId, 'STOP_RENTAL_SUCCESS');
      await _endRental(bikeId, userId, status: 'OK');
    } else {
      mqtt.publishToApp(bikeId, 'STOP_RENTAL_FAIL=$userId');
      mqtt.publish(bikeId, 'STOP_RENTAL_FAIL');
      debugPrint(
        '[Rental] STOP_RENTAL_FAIL bikeId=$bikeId userId=$userId — outside parking zone',
      );
    }
  }

  // ---- Start rental --------------------------------------------------

  Future<void> _handleStartRental(String bikeId, String userId) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    if (mqtt == null || deviceProvider == null) return;

    debugPrint('[Rental] START_RENTAL bikeId=$bikeId userId=$userId');

    if (!_userTokens.containsKey(userId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_USER_NOT_FOUND');
      return;
    }

    final balance = _userTokens[userId] ?? 0;
    if (balance < FeatureConfig.minTokenToRent) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_INSUFFICIENT_BALANCE');
      debugPrint('[Rental] ERR_INSUFFICIENT_BALANCE: $userId balance=$balance');
      return;
    }

    if (_activeRentals.containsKey(bikeId) ||
        _inProgressBikes.contains(bikeId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_BIKE_UNAVAILABLE');
      return;
    }

    final battery = deviceProvider.deviceById(bikeId)?.latest?.battery;
    if (battery != null && battery < FeatureConfig.minBatteryToRentPercent) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_LOW_BATTERY');
      debugPrint('[Rental] ERR_LOW_BATTERY: bikeId=$bikeId battery=$battery%');
      return;
    }

    // Deduct first block deposit and mark in-progress
    _userTokens[userId] = balance - FeatureConfig.minTokenToRent;
    _persistUserState(userId);
    _inProgressBikes.add(bikeId);
    notifyListeners();

    // startTime captured before the cmd so the timestamp sent to device matches
    // the session start recorded in _activeRentals and the trip doc.
    final startTime = DateTime.now();
    final success = await deviceProvider.sendStartRental(
      bikeId,
      _toRentalTs(startTime),
    );
    _inProgressBikes.remove(bikeId);

    if (!success) {
      _userTokens[userId] =
          (_userTokens[userId] ?? 0) + FeatureConfig.minTokenToRent;
      _persistUserState(userId);
      notifyListeners();
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_START_TIMEOUT');
      return;
    }

    _activeRentals[bikeId] = ActiveRental(
      bikeId: bikeId,
      userId: userId,
      startTime: startTime,
      chargedTokens: FeatureConfig.minTokenToRent,
    );
    notifyListeners();

    mqtt.publishToApp(
      bikeId,
      'START_RENTAL_SUCCESS=$userId,${_toVietnamTime(startTime)}',
    );
    debugPrint('[Rental] START_RENTAL_SUCCESS bikeId=$bikeId userId=$userId');

    _startBlockTimer(bikeId, userId);
  }

  // ---- Block timer ---------------------------------------------------

  void _startBlockTimer(String bikeId, String userId) {
    _blockTimers[bikeId]?.cancel();
    _blockHundredths[bikeId] = 0;
    _blockTimers[bikeId] = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _blockTick(bikeId, userId),
    );
  }

  void _blockTick(String bikeId, String userId) {
    if (!_activeRentals.containsKey(bikeId)) {
      _blockTimers[bikeId]?.cancel();
      _blockTimers.remove(bikeId);
      _blockHundredths.remove(bikeId);
      return;
    }
    /* Frozen while locked — keep the timer alive but stop accumulating
     * so the user isn't charged further. */
    if (_lockedUsers.contains(userId)) return;
    final int factor = _pausedBikes.contains(bikeId) ? 50 : 100;
    final int next = (_blockHundredths[bikeId] ?? 0) + factor;
    _blockHundredths[bikeId] = next;
    final int blockHundredths = FeatureConfig.rentalBlockDurationsSeconds * 100;
    if (next >= blockHundredths) {
      _blockHundredths[bikeId] = next - blockHundredths;
      _onRentalBlock(bikeId, userId);
    }
  }

  void _onRentalBlock(String bikeId, String userId) {
    if (!_activeRentals.containsKey(bikeId)) {
      _blockTimers[bikeId]?.cancel();
      _blockTimers.remove(bikeId);
      _blockHundredths.remove(bikeId);
      return;
    }
    if (_lockedUsers.contains(userId)) return;

    final balance = _userTokens[userId] ?? 0;
    final int rate = FeatureConfig.minTokenToRent;
    /* Pay block from balance first, accrue any shortfall as debt. */
    final int chargeFromBalance = math.min(balance, rate);
    final int shortfall = rate - chargeFromBalance;
    _userTokens[userId] = balance - chargeFromBalance;

    final r = _activeRentals[bikeId]!;
    final int newCharged = r.chargedTokens + rate;
    _activeRentals[bikeId] = r.withChargedTokens(newCharged);

    _mqtt?.publishToApp(bikeId, 'BLOCK_TICK=${newCharged ~/ rate},$newCharged');

    if (shortfall > 0) {
      final int newDebt = (_userDebt[userId] ?? 0) + shortfall;
      _userDebt[userId] = newDebt;
      _debtStartedAt[userId] ??= DateTime.now();
      final DateTime debtStarted = _debtStartedAt[userId]!;
      final bool exceedsAmount = newDebt >= FeatureConfig.rentalDebtMaxTokens;
      final bool exceedsTime =
          DateTime.now().difference(debtStarted).inDays >=
          FeatureConfig.rentalDebtMaxDays;

      if (exceedsAmount || exceedsTime) {
        _lockedUsers.add(userId);
        _persistUserState(userId);
        _blockTimers[bikeId]?.cancel();
        _blockTimers.remove(bikeId);
        _blockHundredths.remove(bikeId);
        _mqtt?.publishToApp(bikeId, 'RENTAL_NOTI_LIMIT=$newDebt');
        _mqtt?.publish(bikeId, 'RENTAL_NOTI_LIMIT');
        notifyListeners();
        debugPrint(
          '[Rental] LOCK bikeId=$bikeId userId=$userId debt=$newDebt '
          'reason=${exceedsAmount ? "amount" : "time"}',
        );
        return;
      }

      _persistUserState(userId);
      _mqtt?.publishToApp(bikeId, 'WARN_DEBT=$newDebt');
      _mqtt?.publish(bikeId, 'WARN_DEBT');
      notifyListeners();
      debugPrint(
        '[Rental] WARN_DEBT bikeId=$bikeId userId=$userId debt=$newDebt',
      );
      return;
    }

    /* Block paid in full. Warn if next block won't be affordable. */
    _persistUserState(userId);
    notifyListeners();
    debugPrint(
      '[Rental] Block charged bikeId=$bikeId rate=$rate balance=${_userTokens[userId]}',
    );
    if ((_userTokens[userId] ?? 0) < rate) {
      _mqtt?.publishToApp(bikeId, 'WARN_LOW_BALANCE');
      _mqtt?.publish(bikeId, 'WARN_LOW_BALANCE');
      debugPrint('[Rental] WARN_LOW_BALANCE bikeId=$bikeId userId=$userId');
    }
  }

  // ---- Pause (app-initiated) -----------------------------------------

  Future<void> _handleAppPause(String bikeId, String userId) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    if (mqtt == null || deviceProvider == null) return;

    final rental = _activeRentals[bikeId];
    if (rental == null || rental.userId != userId) {
      mqtt.publishToApp(bikeId, 'PAUSE_ERR=ERR_NO_ACTIVE_RENTAL');
      return;
    }
    if (_pausedBikes.contains(bikeId)) {
      mqtt.publishToApp(bikeId, 'PAUSE_ERR=ERR_ALREADY_PAUSED');
      return;
    }

    // Bike is active → sendUnlock sends LOCK command
    final locked = await deviceProvider.sendUnlock(bikeId);
    if (!locked) {
      mqtt.publishToApp(bikeId, 'PAUSE_ERR=ERR_LOCK_TIMEOUT');
      return;
    }

    _pausedBikes.add(bikeId);
    notifyListeners();
    mqtt.publishToApp(bikeId, 'PAUSE_SUCCESS=$userId');
    debugPrint('[Rental] PAUSE (app) bikeId=$bikeId userId=$userId');

    _startPauseTimeout(bikeId, userId);
  }

  // ---- Pause (device-initiated via NOTI_PAUSE on bike_id/noti) -------

  void _handleDevicePause(String bikeId) {
    final rental = _activeRentals[bikeId];
    if (rental == null || _pausedBikes.contains(bikeId)) return;

    _pausedBikes.add(bikeId);
    notifyListeners();

    // Ack device and notify app
    _mqtt?.publish(bikeId, 'OK');
    _mqtt?.publishToApp(bikeId, 'PAUSE_SUCCESS=${rental.userId}');
    debugPrint(
      '[Rental] PAUSE (device) bikeId=$bikeId userId=${rental.userId}',
    );

    _startPauseTimeout(bikeId, rental.userId);
  }

  // ---- Resume --------------------------------------------------------

  Future<void> _handleResume(String bikeId, String userId) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    if (mqtt == null || deviceProvider == null) return;

    final rental = _activeRentals[bikeId];
    if (rental == null || rental.userId != userId) {
      mqtt.publishToApp(bikeId, 'RESUME_ERR=ERR_NO_ACTIVE_RENTAL');
      return;
    }
    if (!_pausedBikes.contains(bikeId)) {
      mqtt.publishToApp(bikeId, 'RESUME_ERR=ERR_NOT_PAUSED');
      return;
    }

    // Cancel pause timeout first
    _pauseTimeoutTimers[bikeId]?.cancel();
    _pauseTimeoutTimers.remove(bikeId);

    // Bike is locked/paused → sendUnlock sends UNLOCK command
    final unlocked = await deviceProvider.sendUnlock(bikeId);
    if (!unlocked) {
      mqtt.publishToApp(bikeId, 'RESUME_ERR=ERR_UNLOCK_TIMEOUT');
      // Re-arm pause timeout since bike is still paused
      _startPauseTimeout(bikeId, userId);
      return;
    }

    _pausedBikes.remove(bikeId);
    notifyListeners();
    mqtt.publishToApp(bikeId, 'RESUME_SUCCESS=$userId');
    debugPrint('[Rental] RESUME bikeId=$bikeId userId=$userId');
  }

  // ---- Pause timeout (1 hour) ----------------------------------------

  void _startPauseTimeout(String bikeId, String userId) {
    if (!FeatureConfig.enablePauseTimeLimit) return;
    _pauseTimeoutTimers[bikeId]?.cancel();
    _pauseTimeoutTimers[bikeId] = Timer(
      const Duration(hours: FeatureConfig.pauseTimeoutHours),
      () async {
        _pauseTimeoutTimers.remove(bikeId);
        if (!_activeRentals.containsKey(bikeId)) return;
        debugPrint('[Rental] Pause timeout bikeId=$bikeId → force end rental');
        _pausedBikes.remove(bikeId);
        await _endRental(bikeId, userId, status: 'ERR_TIME_LIMIT_EXCEEDED');
      },
    );
  }

  // ---- End rental ----------------------------------------------------

  Future<void> _endRental(
    String bikeId,
    String userId, {
    String? status,
    bool addPenalty = false,
  }) async {
    final endTime = DateTime.now();
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    final rental = _activeRentals[bikeId];
    if (mqtt == null || deviceProvider == null || rental == null) return;

    final locked = await deviceProvider.sendLock(bikeId);
    if (!locked) {
      debugPrint(
        '[Rental] _endRental: LOCK timeout bikeId=$bikeId — continuing',
      );
    }

    _activeRentals.remove(bikeId);
    _pausedBikes.remove(bikeId);
    _blockTimers[bikeId]?.cancel();
    _blockTimers.remove(bikeId);
    _blockHundredths.remove(bikeId);
    notifyListeners();

    // Build a session route from the GPS collected during this rental.
    _finalizeSessionRoute(bikeId, rental, endTime);

    // Record completed window so late-arriving GPS data can be merged
    final tripId = _toRentalTs(rental.startTime);
    final windows = _completedWindows.putIfAbsent(bikeId, () => []);
    windows.add(
      _RentalWindow(
        tripId: tripId,
        userId: rental.userId,
        startTime: rental.startTime,
        endTime: endTime,
      ),
    );
    if (windows.length > 5) windows.removeAt(0);
    unawaited(
      FirebaseRepo.instance.finalizeTripEntry(
        bikeId,
        tripId: tripId,
        endTime: endTime,
      ),
    );

    final billAmount =
        rental.chargedTokens +
        (addPenalty ? FeatureConfig.outOfZonePenaltyTokens : 0);

    final statusPart = status != null ? ',<status=$status>' : '';
    mqtt.publishToApp(
      bikeId,
      'END_RENTAL=${rental.userId},$billAmount$statusPart',
    );
    debugPrint(
      '[Rental] END_RENTAL bikeId=$bikeId userId=$userId bill=$billAmount status=$status',
    );
  }

  // ---- Parking zones -------------------------------------------------

  // Returns true if the bike's latest GPS is within any parking zone.
  bool _isInValidParkingArea(String bikeId) {
    final data = _deviceProvider?.deviceById(bikeId)?.latest;
    if (data == null || !data.hasGps) return false;

    for (var i = 0; i < _zones.length; i++) {
      final zone = _zones[i];
      final distance = _haversineMeters(
        data.lat!,
        data.lng!,
        zone.lat,
        zone.lng,
      );
      if (distance <= zone.radiusMeters) return true;
      debugPrint(
        '[Rental] GPS check bikeId=$bikeId zone=${zone.id} '
        'distance=${distance.toStringAsFixed(1)}m',
      );
    }
    return false;
  }

  // Haversine distance in metres between two GPS coordinates.
  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthR = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthR * 2 * math.asin(math.sqrt(a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  // ---- Stop rental (manual / admin) ----------------------------------

  void stopRental(String bikeId) {
    final rental = _activeRentals[bikeId];
    if (rental == null) return;
    _blockTimers[bikeId]?.cancel();
    _blockTimers.remove(bikeId);
    _blockHundredths.remove(bikeId);
    _graceTimers[bikeId]?.cancel();
    _graceTimers.remove(bikeId);
    _graceCheckers[bikeId]?.cancel();
    _graceCheckers.remove(bikeId);
    _pauseTimeoutTimers[bikeId]?.cancel();
    _pauseTimeoutTimers.remove(bikeId);
    _endRental(bikeId, rental.userId);
  }

  @override
  void dispose() {
    _rentalSub?.cancel();
    _tokenSub?.cancel();
    _notiSub?.cancel();
    _dataSub?.cancel();
    _zonesSub?.cancel();
    _usersSub?.cancel();
    for (final t in _blockTimers.values) {
      t.cancel();
    }
    for (final t in _graceTimers.values) {
      t.cancel();
    }
    for (final t in _graceCheckers.values) {
      t.cancel();
    }
    for (final t in _pauseTimeoutTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ---- Trip data sync --------------------------------------------------

  void _onDeviceData(MqttDataMessage msg) {
    final bikeId = msg.deviceId;
    final data = msg.data;
    if (!data.hasGps) return;

    final point = <String, dynamic>{
      'time': data.timestamp.toIso8601String(),
      'lat': data.lat,
      'lon': data.lng,
      'speedKmh': data.velocityKmh ?? 0.0,
    };

    // Active rental — data belongs to current trip
    final active = _activeRentals[bikeId];
    if (active != null && !data.timestamp.isBefore(active.startTime)) {
      if (FeatureConfig.saveTripLocal || FeatureConfig.saveTripFirestore) {
        _accumulateRentalPoint(bikeId, data);
      }
      unawaited(
        FirebaseRepo.instance.mergeTripPoint(
          bikeId,
          tripId: _toRentalTs(active.startTime),
          userId: active.userId,
          startTime: active.startTime,
          point: point,
        ),
      );
      return;
    }

    // Late-arriving data — check completed rental windows
    for (final w in (_completedWindows[bikeId] ?? []).reversed) {
      if (!data.timestamp.isBefore(w.startTime) &&
          !data.timestamp.isAfter(w.endTime)) {
        unawaited(
          FirebaseRepo.instance.mergeTripPoint(
            bikeId,
            tripId: w.tripId,
            userId: w.userId,
            startTime: w.startTime,
            point: point,
          ),
        );
        return;
      }
    }
  }

  // Collect a GPS point (and odometer bounds) for the in-progress rental.
  void _accumulateRentalPoint(String bikeId, DeviceData data) {
    final lat = data.lat, lng = data.lng;
    if (lat != null && lng != null) {
      (_rentalPoints[bikeId] ??= <LatLng>[]).add(LatLng(lat, lng));
    }
    final km = data.totalKm;
    if (km != null) {
      _rentalStartKm.putIfAbsent(bikeId, () => km);
      _rentalLastKm[bikeId] = km;
    }
    final dm = data.distanceM;
    if (dm != null) {
      _rentalLastDistanceM[bikeId] = dm;
    }
  }

  // Build a session HistoryRouteRecord from the points collected during the
  // rental, store it (newest-first display), and best-effort persist it.
  void _finalizeSessionRoute(
    String bikeId,
    ActiveRental rental,
    DateTime endTime,
  ) {
    final points = _rentalPoints.remove(bikeId) ?? const <LatLng>[];
    final startKm = _rentalStartKm.remove(bikeId) ?? 0.0;
    final endKm = _rentalLastKm.remove(bikeId) ?? startKm;
    final lastDistanceM = _rentalLastDistanceM.remove(bikeId);
    if (points.isEmpty) return;

    // Trip distance = the final device `distance_m` (meters → km). Falls back
    // to the odometer delta when no distance_m was received.
    final odoDistanceKm = (endKm - startKm) < 0 ? 0.0 : (endKm - startKm);
    final distanceKm = lastDistanceM != null
        ? lastDistanceM / 1000.0
        : odoDistanceKm;

    final start = rental.startTime;
    final dayKey =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final record = HistoryRouteRecord(
      id: 'rental_${_toRentalTs(start)}',
      vehicleId: bikeId,
      dayKey: dayKey,
      startAt: start,
      endAt: endTime,
      isClosed: true,
      startTotalKm: startKm,
      endTotalKm: endKm,
      distanceKm: distanceKm,
      points: points,
    );

    // Save in parallel, each gated by its own config flag.
    if (FeatureConfig.saveTripLocal) {
      (_sessionRoutes[bikeId] ??= <HistoryRouteRecord>[]).add(record);
      notifyListeners();
      unawaited(_persistSessionRoutes());
    }
    if (FeatureConfig.saveTripFirestore) {
      unawaited(FirebaseRepo.instance.upsertHistoryRouteFromWeb(record));
    }
  }
}

/* Private classes ---------------------------------------------------- */
class _RentalWindow {
  final String tripId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;

  const _RentalWindow({
    required this.tripId,
    required this.userId,
    required this.startTime,
    required this.endTime,
  });
}

/* End of file -------------------------------------------------------- */
