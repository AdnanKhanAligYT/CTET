/// Mirrors a `notes_chapters` row (see `supabase/migration_notes.sql`) —
/// one chapter under a fixed Notes subject; its content lives separately
/// as an ordered list of `NotesBlock`s.
class NotesChapter {
  const NotesChapter({
    required this.id,
    required this.subject,
    required this.unit,
    required this.chapterNumber,
    required this.chapterName,
    required this.sortOrder,
  });

  final String id;
  final String subject;
  final String? unit;
  final int? chapterNumber;
  final String chapterName;
  final int sortOrder;

  factory NotesChapter.fromMap(Map<String, dynamic> map) {
    return NotesChapter(
      id: map['id'] as String,
      subject: map['subject'] as String? ?? '',
      unit: map['unit'] as String?,
      chapterNumber: (map['chapter_number'] as num?)?.toInt(),
      chapterName: map['chapter_name'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
