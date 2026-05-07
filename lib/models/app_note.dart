// @file       app_note.dart
// @brief      Data model for App Note.

/* Imports ------------------------------------------------------------ */
import 'package:cloud_firestore/cloud_firestore.dart';

/* Public classes ----------------------------------------------------- */
class AppNote {
  const AppNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppNote.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawUpdatedAt = map['updatedAt'];

    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is DateTime
        ? rawCreatedAt
        : DateTime.now();

    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : rawUpdatedAt is DateTime
        ? rawUpdatedAt
        : createdAt;

    return AppNote(
      id: id,
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/* End of file -------------------------------------------------------- */
