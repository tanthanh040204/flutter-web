// @file       rental_user_info.dart
// @brief      User info shown on web when a mobile user rents a vehicle.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class RentalUserInfo {
  const RentalUserInfo({
    required this.wireUserId,
    this.uid,
    this.fullName,
    this.employeeCode,
    this.phone,
    this.email,
    this.role,
    this.balance = 0,
    this.depositLocked = 0,
    this.isActive = true,
    this.currentSessionId,
    this.currentBikeId,
    this.currentBikeStartedAt,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  final String wireUserId;
  final String? uid;
  final String? fullName;
  final String? employeeCode;
  final String? phone;
  final String? email;
  final String? role;
  final int balance;
  final int depositLocked;
  final bool isActive;
  final String? currentSessionId;
  final String? currentBikeId;
  final DateTime? currentBikeStartedAt;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    final mail = (email ?? '').trim();
    if (mail.isNotEmpty) return mail;
    final tel = (phone ?? '').trim();
    if (tel.isNotEmpty) return tel;
    return wireUserId;
  }

  static RentalUserInfo fromMap(String id, Map<String, dynamic> map) {
    final String wireId = _asString(map['wireUserId']) ??
        _asString(map['userId']) ??
        _asString(map['id']) ??
        id;

    return RentalUserInfo(
      wireUserId: wireId,
      uid: _asString(map['uid']),
      fullName: _asString(map['fullName']) ??
          _asString(map['displayName']) ??
          _asString(map['name']),
      employeeCode: _asString(map['employeeCode']),
      phone: _asString(map['phone']),
      email: _asString(map['email']),
      role: _asString(map['role']),
      balance: _asInt(map['balance']) ?? _asInt(map['tokens']) ?? 0,
      depositLocked: _asInt(map['depositLocked']) ?? 0,
      isActive: _asBool(map['isActive']) ?? true,
      currentSessionId: _asString(map['currentSessionId']),
      currentBikeId: _asString(map['currentBikeId']) ?? _asString(map['bikeId']),
      currentBikeStartedAt: _toDate(map['currentBikeStartedAt']) ??
          _toDate(map['startedAt']),
      lastLoginAt: _toDate(map['lastLoginAt']),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  RentalUserInfo copyWith({
    String? uid,
    String? fullName,
    String? employeeCode,
    String? phone,
    String? email,
    String? role,
    int? balance,
    int? depositLocked,
    bool? isActive,
    String? currentSessionId,
    String? currentBikeId,
    DateTime? currentBikeStartedAt,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCurrentSession = false,
  }) {
    return RentalUserInfo(
      wireUserId: wireUserId,
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      employeeCode: employeeCode ?? this.employeeCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      balance: balance ?? this.balance,
      depositLocked: depositLocked ?? this.depositLocked,
      isActive: isActive ?? this.isActive,
      currentSessionId: clearCurrentSession
          ? null
          : currentSessionId ?? this.currentSessionId,
      currentBikeId: clearCurrentSession ? null : currentBikeId ?? this.currentBikeId,
      currentBikeStartedAt: clearCurrentSession
          ? null
          : currentBikeStartedAt ?? this.currentBikeStartedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'wireUserId': wireUserId,
      'uid': uid,
      'fullName': fullName,
      'employeeCode': employeeCode,
      'phone': phone,
      'email': email,
      'role': role,
      'balance': balance,
      'tokens': balance,
      'depositLocked': depositLocked,
      'isActive': isActive,
      'currentSessionId': currentSessionId,
      'currentBikeId': currentBikeId,
      'currentBikeStartedAt': currentBikeStartedAt,
      'lastLoginAt': lastLoginAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/* End of file -------------------------------------------------------- */
