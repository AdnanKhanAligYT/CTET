/// Mirrors a `notes_blocks` row (see `supabase/migration_notes.sql`) — one
/// piece of a chapter's content. [blockType] decides how [content] is
/// shaped and how NotesBlockView renders it; kept as a raw untyped map
/// rather than a sealed class per block_type so a new type the admin
/// starts using doesn't need an app update to store (only to render
/// specially — an unrecognized type just renders nothing).
class NotesBlock {
  const NotesBlock({
    required this.id,
    required this.blockType,
    required this.content,
    required this.sortOrder,
  });

  final String id;
  final String blockType;
  final Map<String, dynamic> content;
  final int sortOrder;

  factory NotesBlock.fromMap(Map<String, dynamic> map) {
    return NotesBlock(
      id: map['id'] as String,
      blockType: map['block_type'] as String? ?? '',
      content: (map['content'] as Map?)?.cast<String, dynamic>() ?? const {},
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
