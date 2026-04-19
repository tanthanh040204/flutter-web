// @file       rental_provider.dart
// @brief      List of user ID

/* Imports ------------------------------------------------------------ */
import 'package:flutter/foundation.dart';

/* Public classes ----------------------------------------------------- */
class RentalProvider extends ChangeNotifier {
  final List<String> _userIds = [
    'user_1234567890',
    // 'user_0987654321',
  ];

  List<String> get userIds => List.unmodifiable(_userIds);

  void addUserId(String userId) {
    final id = userId.trim();
    if (id.isEmpty || _userIds.contains(id)) return;
    _userIds.add(id);
    notifyListeners();
  }

  void removeUserId(String userId) {
    if (_userIds.remove(userId)) notifyListeners();
  }
}

/* End of file -------------------------------------------------------- */
