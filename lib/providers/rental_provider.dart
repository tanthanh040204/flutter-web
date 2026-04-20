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
    this.chargedBlocks = 1,
  });

  final String bikeId;
  final String userId;
  final DateTime startTime;
  final int chargedBlocks;

  ActiveRental withChargedBlocks(int n) => ActiveRental(
    bikeId: bikeId,
    userId: userId,
    startTime: startTime,
    chargedBlocks: n,
  );
}

/* Public classes ----------------------------------------------------- */
class RentalProvider extends ChangeNotifier {
  // ---- Add user_id entries here manually ----
  final List<String> _userIds = [
    'user_1234567890',
    // 'user_0987654321',
  ];

  // Center coordinates of each parking zone.
  static const List<({double lat, double lng})> _parkingZoneCenters = [
    (lat: 10.762622, lng: 106.660172), // Parking A - District 3
    (lat: 10.773461, lng: 106.698055), // Parking B - Binh Thanh District
    (lat: 10.780000, lng: 106.680000), // Parking C - Phu Nhuan District
  ];

  // Radius (metres) for each zone — same index as _parkingZoneCenters.
  static const List<double> _parkingZoneRadii = [
    50.0, // Parking A
    80.0, // Parking B
    60.0, // Parking C
  ];

  // bikeId → 30-min block timer
  final Map<String, Timer> _blockTimers = {};
  // bikeId → 15-min grace timer (out-of-balance, outside parking)
  final Map<String, Timer> _graceTimers = {};
  // bikeId → position poll timer during grace period
  final Map<String, Timer> _graceCheckers = {};

  // userId → current token balance
  final Map<String, int> _userTokens = {};

  // bikeId → active rental session
  final Map<String, ActiveRental> _activeRentals = {};

  // Bikes currently in the middle of an async UNLOCK handshake
  final Set<String> _inProgressBikes = {};

  StreamSubscription<MqttRentalRequestMessage>? _rentalSub;
  StreamSubscription<MqttTokenRequestMessage>? _tokenSub;
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
  }

  // ---- Token requests ------------------------------------------------

  /// Parse messages from topic Q7M4K2P/request to add tokens to user accounts.
  void _onTokenRequest(MqttTokenRequestMessage msg) {
    final mqtt = _mqtt;
    if (!msg.raw.startsWith('REQ_ADD_TOKEN=')) return;
    final parts = msg.raw.substring('REQ_ADD_TOKEN='.length).split(',');
    if (parts.length < 2) return;

    final userId = parts[0].trim();
    final amount = int.tryParse(parts[1].trim());
    if (amount == null || amount <= 0) return;

    if (!_userIds.contains(userId)) {
      debugPrint('[Token] ERR_USER_NOT_FOUND: $userId');
      return;
    }

    _userTokens[userId] = (_userTokens[userId] ?? 0) + amount;
    notifyListeners();
    final mes = 'ADD_TOKEN_SUCCESS=${_userTokens[userId]}';
    final topic = '$userId/response';
    mqtt?.publishRaw(topic, mes);
    debugPrint('[Token] +$amount → $userId (total: ${_userTokens[userId]})');
  }

  // ---- Rental requests -----------------------------------------------

  /// Process rental requests from mobile app
  void _onRentalRequest(MqttRentalRequestMessage msg) {
    if (msg.raw.startsWith('START_RENTAL=')) {
      final userId = msg.raw.substring('START_RENTAL='.length).trim();
      _handleStartRental(msg.bikeId, userId);
    }
  }

  Future<void> _handleStartRental(String bikeId, String userId) async {
    final mqtt = _mqtt;
    final deviceProvider = _deviceProvider;
    if (mqtt == null || deviceProvider == null) return;

    debugPrint('[Rental] START_RENTAL bikeId=$bikeId userId=$userId');

    // 1. Check user is registered
    if (!_userIds.contains(userId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_USER_NOT_FOUND');
      debugPrint('[Rental] ERR_USER_NOT_FOUND: $userId');
      return;
    }

    // 2. Check minimum token balance for rental
    final balance = _userTokens[userId] ?? 0;
    if (balance < FeatureConfig.minTokenToRent) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_INSUFFICIENT_BALANCE');
      debugPrint('[Rental] ERR_INSUFFICIENT_BALANCE: $userId balance=$balance');
      return;
    }

    // 3. Check bike is not already rented or unlock in progress
    if (_activeRentals.containsKey(bikeId) ||
        _inProgressBikes.contains(bikeId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_BIKE_UNAVAILABLE');
      debugPrint('[Rental] ERR_BIKE_UNAVAILABLE: $bikeId');
      return;
    }

    // 4. Hold deposit and mark in-progress
    _userTokens[userId] = balance - FeatureConfig.minTokenToRent;
    _inProgressBikes.add(bikeId);
    notifyListeners();

    // 5. Send UNLOCK via DeviceProvider — updates device lock state on OK
    final success = await deviceProvider.sendUnlock(bikeId);
    _inProgressBikes.remove(bikeId);

    if (!success) {
      // Refund deposit and report failure
      _userTokens[userId] =
          (_userTokens[userId] ?? 0) + FeatureConfig.minTokenToRent;
      notifyListeners();
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_UNLOCK_TIMEOUT');
      debugPrint('[Rental] ERR_UNLOCK_TIMEOUT: $bikeId');
      return;
    }

    // 6. Record active session and notify app
    final startTime = DateTime.now();
    _activeRentals[bikeId] = ActiveRental(
      bikeId: bikeId,
      userId: userId,
      startTime: startTime,
      chargedBlocks: 1,
    );
    notifyListeners();

    final iso = _toVietnamTime(startTime);
    mqtt.publishToApp(bikeId, 'START_RENTAL_SUCCESS=$userId,$iso');
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

    if (balance >= FeatureConfig.minTokenToRent * 2) {
      // Enough for this block + at least one more — deduct and continue
      _userTokens[userId] = balance - FeatureConfig.minTokenToRent;
      final reduce = _activeRentals[bikeId]!;
      _activeRentals[bikeId] = reduce.withChargedBlocks(
        reduce.chargedBlocks + 1,
      );
      notifyListeners();
      debugPrint(
        '[Rental] Block charged bikeId=$bikeId balance=${_userTokens[userId]}',
      );
    } else if (balance >= FeatureConfig.minTokenToRent) {
      // Only enough for this block — deduct and warn
      _userTokens[userId] = balance - FeatureConfig.minTokenToRent;
      final reduce = _activeRentals[bikeId]!;
      _activeRentals[bikeId] = reduce.withChargedBlocks(
        reduce.chargedBlocks + 1,
      );
      notifyListeners();

      _mqtt?.publishToApp(bikeId, 'WARN_LOW_BALANCE');
      _mqtt?.publish(bikeId, 'WARN_LOW_BALANCE');
      debugPrint('[Rental] WARN_LOW_BALANCE bikeId=$bikeId userId=$userId');
    } else {
      // Cannot pay for another block — stop timer and handle
      _blockTimers[bikeId]?.cancel();
      _blockTimers.remove(bikeId);
      _handleOutOfBalance(bikeId, userId);
    }
  }

  // ---- Out-of-balance -------------------------------------------

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

    // Send LOCK to device (sendUnlock sends LOCK when bike is in active state)
    final locked = await deviceProvider.sendUnlock(bikeId);
    if (!locked) {
      debugPrint(
        '[Rental] _endRental: LOCK timeout bikeId=$bikeId — continuing',
      );
    }

    _activeRentals.remove(bikeId);
    _blockTimers[bikeId]?.cancel();
    _blockTimers.remove(bikeId);
    notifyListeners();

    final billAmount =
        rental.chargedBlocks * FeatureConfig.minTokenToRent +
        (addPenalty ? FeatureConfig.outOfZonePenaltyTokens : 0);

    final statusPart = status != null ? ',<status=$status>' : '';
    mqtt.publishToApp(
      bikeId,
      'END_RENTAL=${rental.userId},$billAmount$statusPart',
    );
    debugPrint(
      '[Rental] END_RENTAL bikeId=$bikeId userId=$userId '
      'bill=$billAmount status=$status',
    );
  }

  // Returns true if the bike's latest GPS is within any parking zone.
  bool _isInValidParkingArea(String bikeId) {
    final data = _deviceProvider?.deviceById(bikeId)?.latest;
    if (data == null || !data.hasGps) return false;

    for (var i = 0; i < _parkingZoneCenters.length; i++) {
      final zone = _parkingZoneCenters[i];
      final radius = _parkingZoneRadii[i];
      if (_dentaMeters(data.lat!, data.lng!, zone.lat, zone.lng) <= radius) {
        return true;
      }
    }
    return false;
  }

  // Haversine distance in metres between two GPS coordinates.
  static double _dentaMeters(
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
    _endRental(bikeId, rental.userId);
  }

  @override
  void dispose() {
    _rentalSub?.cancel();
    _tokenSub?.cancel();
    for (final timer in _blockTimers.values) {
      timer.cancel();
    }
    for (final timer in _graceTimers.values) {
      timer.cancel();
    }
    for (final timer in _graceCheckers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */
