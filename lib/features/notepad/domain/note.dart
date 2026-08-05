/// Mirrors a `notes` row (see `supabase/schema.sql`).
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
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'pinned': pinned,
      'updated_at': DateTime.now().toIso8601String(),
    };
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
