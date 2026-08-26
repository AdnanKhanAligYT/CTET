/// One block inside a `notes_chapters.content` array (see
/// `supabase/migration_notes.sql`) — `{"type": "...", "data": {...}}`.
/// [blockType] decides how [content] is shaped and how NotesBlockView
/// renders it; kept as a raw untyped map rather than a sealed class per
/// block type so a new type the admin starts using doesn't need an app
/// update to store (only to render specially — an unrecognized type just
/// renders nothing).
class NotesBlock {
  const NotesBlock({required this.blockType, required this.content});

  final String blockType;
  final Map<String, dynamic> content;

  factory NotesBlock.fromMap(Map<String, dynamic> map) {
    return NotesBlock(
      blockType: map['type'] as String? ?? '',
      content: (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
