// @file       rental_user.dart
// @brief      Rental user identity + token balance shared via Firestore.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class RentalUser {
  const RentalUser({
    required this.userId,
    required this.tokens,
    this.debt = 0,
    this.debtStartedAt,
    this.isLocked = false,
    this.displayName = '',
    this.isActive = true,
    this.phone,
    this.email,
    this.updatedAt,
  });

  final String userId;
  final int tokens;
  final int debt;
  final DateTime? debtStartedAt;
  final bool isLocked;
  final String displayName;
  final bool isActive;
  // Contact fields mirrored from the app-owned `users` profile. Read-only on
  // web (not written back via toMap), so web never clobbers them.
  final String? phone;
  final String? email;
  final DateTime? updatedAt;

  factory RentalUser.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['updatedAt'];
    final updatedAt = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
        ? raw
        : null;
    final debtRaw = map['debtStartedAt'];
    final debtStartedAt = debtRaw is Timestamp
        ? debtRaw.toDate()
        : debtRaw is DateTime
        ? debtRaw
        : null;

    return RentalUser(
      userId: (map['userId'] ?? id).toString(),
      tokens: _asInt(map['tokens']) ?? 0,
      debt: _asInt(map['debt']) ?? 0,
      debtStartedAt: debtStartedAt,
      isLocked: map['isLocked'] is bool ? map['isLocked'] as bool : false,
      displayName: (map['displayName'] ?? '').toString(),
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      phone: _asString(map['phone']),
      email: _asString(map['email']),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'tokens': tokens,
    'debt': debt,
    'debtStartedAt': debtStartedAt == null
        ? null
        : Timestamp.fromDate(debtStartedAt!),
    'isLocked': isLocked,
    'displayName': displayName,
    'isActive': isActive,
  };

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  // Default seed list — used by `FirebaseRepo` to seed the `rental_users`
  // collection on first run, and by `RentalProvider` as the offline /
  // pre-stream fallback. Keep in sync by always referencing this constant
  // rather than duplicating literals.
  static const List<RentalUser> defaultSeed = <RentalUser>[
    RentalUser(userId: 'user_1234567890', tokens: 0),
    RentalUser(userId: 'user_1132298001', tokens: 0),
    RentalUser(userId: 'user_0987654321', tokens: 0),
  ];
}

/* End of file -------------------------------------------------------- */
