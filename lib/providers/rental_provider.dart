// @file       rental_provider.dart
// @brief      Manages registered rental user IDs, active rentals, and token balances.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import '../config/feature_config.dart';
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
  // ---- Add user_id entries here manually ----
  final List<String> _userIds = [
    'user_1234567890',
    // 'user_0987654321',
  ];

  // bikeId → 30-min block timer
  final Map<String, Timer> _blockTimers = {};
  // bikeId → 15-min out-of-balance grace timer
  final Map<String, Timer> _graceTimers = {};
  // bikeId → position poll timer during grace period
  final Map<String, Timer> _graceCheckers = {};
  // bikeId → 1-hour pause timeout timer
  final Map<String, Timer> _pauseTimeoutTimers = {};

  // userId → current token balance
  final Map<String, int> _userTokens = {};

  // bikeId → active rental session
  final Map<String, ActiveRental> _activeRentals = {};

  // Bikes currently paused (50% rate applies)
  final Set<String> _pausedBikes = {};

  // Bikes currently in the middle of an async UNLOCK handshake
  final Set<String> _inProgressBikes = {};

  StreamSubscription<MqttRentalRequestMessage>? _rentalSub;
  StreamSubscription<MqttTokenRequestMessage>? _tokenSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  MqttService? _mqtt;
  DeviceProvider? _deviceProvider;

  String _toVietnamTime(DateTime value) {
    final vn = value.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    final year = vn.year.toString().padLeft(4, '0');
    return '$year/${two(vn.month)}/${two(vn.day)}-'
        '${two(vn.hour)}:${two(vn.minute)}:${two(vn.second)}';
  }

  List<String> get userIds => List.unmodifiable(_userIds);
  List<ActiveRental> get activeRentals =>
      List.unmodifiable(_activeRentals.values.toList());

  ActiveRental? activeRentalForBike(String bikeId) => _activeRentals[bikeId];
  bool isBikeRented(String bikeId) => _activeRentals.containsKey(bikeId);
  bool isBikePaused(String bikeId) => _pausedBikes.contains(bikeId);
  int tokensOf(String userId) => _userTokens[userId] ?? 0;

  void addUserId(String userId) {
    final id = userId.trim();
    if (id.isEmpty || _userIds.contains(id)) return;
    _userIds.add(id);
    notifyListeners();
  }

  void removeUserId(String userId) {
    if (_userIds.remove(userId)) notifyListeners();
  }

  void bindToMqtt(MqttService mqtt, DeviceProvider deviceProvider) {
    _mqtt = mqtt;
    _deviceProvider = deviceProvider;
    _rentalSub?.cancel();
    _rentalSub = mqtt.rentalRequests.listen(_onRentalRequest);
    _tokenSub?.cancel();
    _tokenSub = mqtt.tokenRequests.listen(_onTokenRequest);
    _notiSub?.cancel();
    _notiSub = mqtt.notifications.listen(_onNotiMessage);
  }

  // ---- Token requests ------------------------------------------------

  void _onTokenRequest(MqttTokenRequestMessage msg) {
    final mqtt = _mqtt;
    if (!msg.raw.startsWith('REQ_ADD_TOKEN=')) return;
    final parts = msg.raw.substring('REQ_ADD_TOKEN='.length).split(',');
    if (parts.length < 2) return;

    final userId = parts[0].trim();
    final amount = int.tryParse(parts[1].trim());

    if (amount == null || amount <= 0) {
      mqtt?.publishRaw('$userId/response', 'RESP_ADD_TOKEN_ERROR=ERR_INVALID_AMOUNT');
      debugPrint('[Token] ERR_INVALID_AMOUNT: userId=$userId raw=${parts[1]}');
      return;
    }

    if (!_userIds.contains(userId)) {
      mqtt?.publishRaw('$userId/response', 'RESP_ADD_TOKEN_ERROR=ERR_USER_NOT_FOUND');
      debugPrint('[Token] ERR_USER_NOT_FOUND: $userId');
      return;
    }

    _userTokens[userId] = (_userTokens[userId] ?? 0) + amount;
    notifyListeners();
    mqtt?.publishRaw('$userId/response', 'RESP_ADD_TOKEN_SUCCESS=${_userTokens[userId]}');
    debugPrint('[Token] +$amount → $userId (total: ${_userTokens[userId]})');
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
      await _endRental(bikeId, userId, status: 'OK');
    } else {
      mqtt.publishToApp(bikeId, 'STOP_RENTAL_FAIL=$userId');
      mqtt.publish(bikeId, 'STOP_RENTAL_FAIL');
      debugPrint('[Rental] STOP_RENTAL_FAIL bikeId=$bikeId userId=$userId — outside parking zone');
    }
  }

  // ---- Start rental --------------------------------------------------

  Future<void> _handleStartRental(String bikeId, String userId) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    if (mqtt == null || deviceProvider == null) return;

    debugPrint('[Rental] START_RENTAL bikeId=$bikeId userId=$userId');

    if (!_userIds.contains(userId)) {
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

    // Deduct first block deposit and mark in-progress
    _userTokens[userId] = balance - FeatureConfig.minTokenToRent;
    _inProgressBikes.add(bikeId);
    notifyListeners();

    final success = await deviceProvider.sendUnlock(bikeId);
    _inProgressBikes.remove(bikeId);

    if (!success) {
      _userTokens[userId] =
          (_userTokens[userId] ?? 0) + FeatureConfig.minTokenToRent;
      notifyListeners();
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_UNLOCK_TIMEOUT');
      return;
    }

    final startTime = DateTime.now();
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
    _blockTimers[bikeId] = Timer.periodic(
      Duration(minutes: FeatureConfig.rentalBlockDurationsMinutes),
      (_) => _onRentalBlock(bikeId, userId),
    );
  }

  void _onRentalBlock(String bikeId, String userId) {
    if (!_activeRentals.containsKey(bikeId)) {
      _blockTimers[bikeId]?.cancel();
      _blockTimers.remove(bikeId);
      return;
    }

    final balance = _userTokens[userId] ?? 0;
    // 50% rate when paused, full rate when active
    final rate = _pausedBikes.contains(bikeId)
        ? FeatureConfig.minTokenToRent ~/ 2
        : FeatureConfig.minTokenToRent;

    if (balance >= rate * 2) {
      // Enough for this block + at least one more — deduct and continue
      _userTokens[userId] = balance - rate;
      final r = _activeRentals[bikeId]!;
      _activeRentals[bikeId] = r.withChargedTokens(r.chargedTokens + rate);
      notifyListeners();
      debugPrint(
        '[Rental] Block charged bikeId=$bikeId rate=$rate balance=${_userTokens[userId]}',
      );
    } else if (balance >= rate) {
      // Last affordable block — deduct and warn
      _userTokens[userId] = balance - rate;
      final r = _activeRentals[bikeId]!;
      _activeRentals[bikeId] = r.withChargedTokens(r.chargedTokens + rate);
      notifyListeners();
      _mqtt?.publishToApp(bikeId, 'WARN_LOW_BALANCE');
      _mqtt?.publish(bikeId, 'WARN_LOW_BALANCE');
      debugPrint('[Rental] WARN_LOW_BALANCE bikeId=$bikeId userId=$userId');
    } else {
      // Cannot pay — stop timer and handle out-of-balance
      _blockTimers[bikeId]?.cancel();
      _blockTimers.remove(bikeId);
      _handleOutOfBalance(bikeId, userId);
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
    _pauseTimeoutTimers[bikeId]?.cancel();
    _pauseTimeoutTimers[bikeId] = Timer(const Duration(hours: 1), () async {
      _pauseTimeoutTimers.remove(bikeId);
      if (!_activeRentals.containsKey(bikeId)) return;
      debugPrint('[Rental] Pause timeout bikeId=$bikeId → force end rental');
      _pausedBikes.remove(bikeId);
      await _endRental(bikeId, userId, status: 'ERR_TIME_LIMIT_EXCEEDED');
    });
  }

  // ---- Out-of-balance flow -------------------------------------------

  Future<void> _handleOutOfBalance(String bikeId, String userId) async {
    final mqtt = _mqtt;
    if (mqtt == null) return;

    debugPrint('[Rental] OUT_OF_BALANCE bikeId=$bikeId userId=$userId');

    if (_isInValidParkingArea(bikeId)) {
      await _endRental(bikeId, userId);
    } else {
      mqtt.publishToApp(bikeId, 'WARN_OUT_OF_BALANCE');
      mqtt.publish(bikeId, 'WARN_OUT_OF_BALANCE');
      debugPrint('[Rental] WARN_OUT_OF_BALANCE grace started bikeId=$bikeId');

      // Poll GPS every 30 s to detect when bike returns to a valid zone
      _graceCheckers[bikeId]?.cancel();
      _graceCheckers[bikeId] = Timer.periodic(const Duration(seconds: 30), (t) {
        if (!_activeRentals.containsKey(bikeId)) {
          t.cancel();
          _graceCheckers.remove(bikeId);
          return;
        }
        if (_isInValidParkingArea(bikeId)) {
          t.cancel();
          _graceCheckers.remove(bikeId);
          _graceTimers[bikeId]?.cancel();
          _graceTimers.remove(bikeId);
          _endRental(bikeId, userId, status: 'ERR_TIME_LIMIT_WARNING');
        }
      });

      // Hard 15-minute deadline
      _graceTimers[bikeId]?.cancel();
      _graceTimers[bikeId] = Timer(const Duration(minutes: 15), () {
        _graceTimers.remove(bikeId);
        _graceCheckers[bikeId]?.cancel();
        _graceCheckers.remove(bikeId);
        if (_activeRentals.containsKey(bikeId)) {
          _endRental(
            bikeId,
            userId,
            status: 'ERR_TIME_LIMIT_EXCEEDED',
            addPenalty: true,
          );
        }
      });
    }
  }

  // ---- End rental ----------------------------------------------------

  Future<void> _endRental(
    String bikeId,
    String userId, {
    String? status,
    bool addPenalty = false,
  }) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    final rental = _activeRentals[bikeId];
    if (mqtt == null || deviceProvider == null || rental == null) return;

    // Send LOCK to device (sendUnlock sends LOCK when bike is active/locked)
    final locked = await deviceProvider.sendUnlock(bikeId);
    if (!locked) {
      debugPrint(
        '[Rental] _endRental: LOCK timeout bikeId=$bikeId — continuing',
      );
    }

    _activeRentals.remove(bikeId);
    _pausedBikes.remove(bikeId);
    _blockTimers[bikeId]?.cancel();
    _blockTimers.remove(bikeId);
    notifyListeners();

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

  // Center coordinates of each parking zone.
  static const List<({double lat, double lng})> _parkingZoneCenters = [
    (lat: 10.762622, lng: 106.660172), // Bãi xe A - Quận 3
    (lat: 10.773461, lng: 106.698055), // Bãi xe B - Quận Bình Thạnh
    (lat: 10.780000, lng: 106.680000), // Bãi xe C - Quận Phú Nhuận
  ];

  // Radius (metres) for each zone — same index as _parkingZoneCenters.
  static const List<double> _parkingZoneRadii = [
    50.0, // Bãi xe A
    80.0, // Bãi xe B
    60.0, // Bãi xe C
  ];

  // Returns true if the bike's latest GPS is within any parking zone.
  bool _isInValidParkingArea(String bikeId) {
    final data = _deviceProvider?.deviceById(bikeId)?.latest;
    if (data == null || !data.hasGps) return false;

    for (var i = 0; i < _parkingZoneCenters.length; i++) {
      final zone = _parkingZoneCenters[i];
      final radius = _parkingZoneRadii[i];
      if (_haversineMeters(data.lat!, data.lng!, zone.lat, zone.lng) <=
          radius) {
        return true;
      }
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
}

/* End of file -------------------------------------------------------- */
