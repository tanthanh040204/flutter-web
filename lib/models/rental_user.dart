// @file       rental_user.dart
// @brief      Rental user identity + token balance shared via Firestore.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class RentalUser {
  const RentalUser({
    required this.userId,
    required this.tokens,
    this.displayName = '',
    this.isActive = true,
    this.updatedAt,
  });

  final String userId;
  final int tokens;
  final String displayName;
  final bool isActive;
  final DateTime? updatedAt;

  factory RentalUser.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['updatedAt'];
    final updatedAt = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
            ? raw
            : null;

    return RentalUser(
      userId: (map['userId'] ?? id).toString(),
      tokens: _asInt(map['tokens']) ?? 0,
      displayName: (map['displayName'] ?? '').toString(),
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'tokens': tokens,
        'displayName': displayName,
        'isActive': isActive,
      };

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/* End of file -------------------------------------------------------- */
