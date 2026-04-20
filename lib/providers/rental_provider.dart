// @file       rental_provider.dart
// @brief      Manages registered rental user IDs, active rentals, and token balances.

/* Imports ------------------------------------------------------------ */
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_provider.dart';
import '../services/mqtt_service.dart';

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
  // Minimum token balance required to start a 30-minute rental session.
  static const int minTokensRequired = 10000;

  // ---- Add user_id entries here manually ----
  final List<String> _userIds = [
    'user_1234567890',
    // 'user_0987654321',
  ];

  Map<String, Timer> _timers = {};

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

    // 2. Check minimum token balance (≥ 10,000 = 30 minutes rental)
    final balance = _userTokens[userId] ?? 0;
    if (balance < minTokensRequired) {
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
    _userTokens[userId] = balance - minTokensRequired;
    _inProgressBikes.add(bikeId);
    notifyListeners();

    // 5. Send UNLOCK via DeviceProvider — updates device lock state on OK
    final success = await deviceProvider.sendUnlock(bikeId);
    _inProgressBikes.remove(bikeId);

    if (!success) {
      // Refund deposit and report failure
      _userTokens[userId] = (_userTokens[userId] ?? 0) + minTokensRequired;
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
    );
    notifyListeners();

    final iso = _toVietnamTime(startTime);
    mqtt.publishToApp(bikeId, 'START_RENTAL_SUCCESS=$userId,$iso');
    debugPrint('[Rental] START_RENTAL_SUCCESS bikeId=$bikeId userId=$userId');
  }

  // ---- Stop rental ---------------------------------------------------

  void stopRental(String bikeId) {
    final rental = _activeRentals.remove(bikeId);
    if (rental == null) return;
    _deviceProvider?.sendUnlock(bikeId);
    notifyListeners();
    debugPrint('[Rental] STOP_RENTAL bikeId=$bikeId userId=${rental.userId}');
  }

  @override
  void dispose() {
    _rentalSub?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */
