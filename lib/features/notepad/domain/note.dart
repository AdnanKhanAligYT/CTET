import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `/users/{uid}/notes/{id}`.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.pinned = false,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? updatedAt;

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      pinned: map['pinned'] as bool? ?? false,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool isCreate = false}) {
    final map = <String, dynamic>{
      'title': title,
      'body': body,
      'pinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isCreate) map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Note copyWith({String? title, String? body, bool? pinned}) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      pinned: pinned ?? this.pinned,
      updatedAt: updatedAt,
    );
  }
}
