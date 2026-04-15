import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.employeeCode,
  });

  final String id;
  final String message;
  final String type;
  final DateTime createdAt;
  final String? employeeCode;

  factory AppNotificationItem.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is DateTime
        ? rawCreatedAt
        : DateTime.now();

    return AppNotificationItem(
      id: id,
      message: (map['message'] ?? '').toString(),
      type: (map['type'] ?? 'general').toString(),
      employeeCode: map['employeeCode']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'type': type,
      'employeeCode': employeeCode,
      'createdAt': createdAt,
    };
  }
}
