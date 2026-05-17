// @file       employee_account.dart
// @brief      Data model for Employee Account.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class EmployeeAccount {
  const EmployeeAccount({
    required this.employeeCode,
    required this.password,
    required this.updatedAt,
  });

  final String employeeCode;
  final String password;
  final DateTime updatedAt;

  factory EmployeeAccount.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawUpdatedAt = map['updatedAt'];
    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt is DateTime
        ? rawUpdatedAt
        : DateTime.now();

    return EmployeeAccount(
      employeeCode: (map['employeeCode'] ?? id ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeCode': employeeCode,
      'password': password,
      'updatedAt': updatedAt,
    };
  }
}

/* End of file -------------------------------------------------------- */