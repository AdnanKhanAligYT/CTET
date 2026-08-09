/// Mirrors an `exams` row (see `supabase/schema.sql`) — either a
/// top-level exam (e.g. "CTET", [parentExamId] null) or a paper under one
/// (e.g. "CTET Paper 1", [parentExamId] pointing at the "CTET" row).
/// Read-only from the app; add/remove/reorder happens outside it, via the
/// reference PHP app's Termux admin tool.
class ExamNode {
  const ExamNode({
    required this.id,
    required this.name,
    required this.parentExamId,
    required this.logoUrl,
    required this.sortOrder,
    required this.isShortcut,
  });

  final String id;
  final String name;
  final String? parentExamId;

  /// Admin-uploaded PNG/JPG/WebP (Supabase Storage, public bucket) shown
  /// before the name in the exam/paper list — null means "show the
  /// default icon instead".
  final String? logoUrl;

  final int sortOrder;

  /// At most one exams row app-wide has this true (enforced by a partial
  /// unique index) — that node shows as a one-tap shortcut above the Mock
  /// Test tile on the dashboard instead of navigating the full tree.
  final bool isShortcut;

  factory ExamNode.fromMap(Map<String, dynamic> map) {
    return ExamNode(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      parentExamId: map['parent_exam_id'] as String?,
      logoUrl: map['logo_url'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isShortcut: map['is_shortcut'] as bool? ?? false,
    );
  }
}
