import 'notes_block.dart';

/// Mirrors a `notes_chapters` row (see `supabase/migration_notes.sql`) —
/// one chapter under a fixed Notes subject. Unlike Syllabus/Questions,
/// its entire content is a single jsonb array on this same row (parsed
/// into [content] below) rather than separate child rows — one JSON per
/// chapter, editable as one unit from Study App's admin panel.
class NotesChapter {
  const NotesChapter({
    required this.id,
    required this.subject,
    required this.unit,
    required this.chapterNumber,
    required this.chapterName,
    required this.sortOrder,
    required this.content,
  });

  final String id;
  final String subject;
  final String? unit;
  final int? chapterNumber;
  final String chapterName;
  final int sortOrder;
  final List<NotesBlock> content;

  factory NotesChapter.fromMap(Map<String, dynamic> map) {
    final rawContent = (map['content'] as List?) ?? const [];
    return NotesChapter(
      id: map['id'] as String,
      subject: map['subject'] as String? ?? '',
      unit: map['unit'] as String?,
      chapterNumber: (map['chapter_number'] as num?)?.toInt(),
      chapterName: map['chapter_name'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      content: rawContent
          .map((b) => NotesBlock.fromMap((b as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
