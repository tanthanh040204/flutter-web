// @file       rental_provider.dart
// @brief      Manages registered rental user IDs, active rentals, and token balances.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/mqtt_service.dart';

/* Private types ------------------------------------------------------ */
class _PendingUnlock {
  const _PendingUnlock({required this.userId, required this.requestedAt});
  final String userId;
  final DateTime requestedAt;
}

/* Public types ------------------------------------------------------- */
class ActiveRental {
  const ActiveRental({
    required this.bikeId,
    required this.userId,
    required this.startTime,
  });

  final String bikeId;
  final String userId;
  final DateTime startTime;
}

/* Public classes ----------------------------------------------------- */
class RentalProvider extends ChangeNotifier {
  // Minimum token balance required to start a 1-hour rental session.
  static const int minTokensRequired = 10000;

  // ---- Add user_id entries here manually ----
  final List<String> _userIds = [
    // 'user_1234567890',
    // 'user_0987654321',
  ];

  // userId → current token balance
  final Map<String, int> _userTokens = {};

  // bikeId → pending (UNLOCK sent, waiting for device OK)
  final Map<String, _PendingUnlock> _pendingUnlocks = {};

  // bikeId → active rental session
  final Map<String, ActiveRental> _activeRentals = {};

  StreamSubscription<MqttRentalRequestMessage>? _rentalSub;
  StreamSubscription<MqttTokenRequestMessage>? _tokenSub;
  StreamSubscription<MqttNotiMessage>? _notiSub;
  MqttService? _mqtt;

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

  void bindToMqtt(MqttService mqtt) {
    _mqtt = mqtt;
    _rentalSub?.cancel();
    _rentalSub = mqtt.rentalRequests.listen(_onRentalRequest);
    _tokenSub?.cancel();
    _tokenSub = mqtt.tokenRequests.listen(_onTokenRequest);
    _notiSub?.cancel();
    _notiSub = mqtt.notifications.listen(_onNotiMessage);
  }

  // ---- Token requests ------------------------------------------------

  void _onTokenRequest(MqttTokenRequestMessage msg) {
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
    debugPrint('[Token] +$amount → $userId (total: ${_userTokens[userId]})');
  }

  // ---- Rental requests -----------------------------------------------

  void _onRentalRequest(MqttRentalRequestMessage msg) {
    if (msg.raw.startsWith('START_RENTAL=')) {
      final userId = msg.raw.substring('START_RENTAL='.length).trim();
      _handleStartRental(msg.bikeId, userId);
    }
  }

  void _handleStartRental(String bikeId, String userId) {
    final mqtt = _mqtt;
    if (mqtt == null) return;

    debugPrint('[Rental] START_RENTAL bikeId=$bikeId userId=$userId');

    // 1. Check user is registered
    if (!_userIds.contains(userId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_USER_NOT_FOUND');
      debugPrint('[Rental] ERR_USER_NOT_FOUND: $userId');
      return;
    }

    // 2. Check minimum token balance (≥ 10,000 = 1 hour rental)
    final balance = _userTokens[userId] ?? 0;
    if (balance < minTokensRequired) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_INSUFFICIENT_BALANCE');
      debugPrint('[Rental] ERR_INSUFFICIENT_BALANCE: $userId balance=$balance');
      return;
    }

    // 3. Check bike is not already rented or pending unlock
    if (_activeRentals.containsKey(bikeId) || _pendingUnlocks.containsKey(bikeId)) {
      mqtt.publishToApp(bikeId, 'RENTAL_ERR=ERR_BIKE_UNAVAILABLE');
      debugPrint('[Rental] ERR_BIKE_UNAVAILABLE: $bikeId');
      return;
    }

    // 4. Hold deposit — reserve minTokensRequired tokens
    _userTokens[userId] = balance - minTokensRequired;
    _pendingUnlocks[bikeId] = _PendingUnlock(
      userId: userId,
      requestedAt: DateTime.now(),
    );
    notifyListeners();

    // 5. Send UNLOCK to device — wait for OK via /noti before confirming to app
    mqtt.publish(bikeId, 'UNLOCK');
    debugPrint('[Rental] UNLOCK sent → $bikeId (waiting for device OK)');
  }

  // ---- Device noti handler -------------------------------------------

  void _onNotiMessage(MqttNotiMessage msg) {
    final pending = _pendingUnlocks[msg.deviceId];
    if (pending == null) return;

    if (msg.message.trim().toUpperCase() != 'OK') return;

    // Device confirmed unlock — record session and notify app
    _pendingUnlocks.remove(msg.deviceId);

    final startTime = DateTime.now();
    _activeRentals[msg.deviceId] = ActiveRental(
      bikeId: msg.deviceId,
      userId: pending.userId,
      startTime: startTime,
    );
    notifyListeners();

    final iso = startTime.toUtc().toIso8601String();
    _mqtt?.publishToApp(msg.deviceId, 'START_RENTAL_SUCCESS=${pending.userId},$iso');
    debugPrint('[Rental] START_RENTAL_SUCCESS bikeId=${msg.deviceId} userId=${pending.userId}');
  }

  // ---- Stop rental ---------------------------------------------------

  void stopRental(String bikeId) {
    final rental = _activeRentals.remove(bikeId);
    if (rental == null) return;
    _mqtt?.publish(bikeId, 'LOCK');
    notifyListeners();
    debugPrint('[Rental] STOP_RENTAL bikeId=$bikeId userId=${rental.userId}');
  }

  @override
  void dispose() {
    _rentalSub?.cancel();
    _tokenSub?.cancel();
    _notiSub?.cancel();
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */
