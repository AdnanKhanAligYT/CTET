import 'test_set.dart';

/// Mirrors an `exams` row (see `supabase/schema.sql`) — a node in the
/// exam/paper/section tree (e.g. "CTET" -> "CTET Paper 2" -> "Science"),
/// any number of levels deep. Read-only from the app; add/remove/reorder
/// happens outside it, via the reference PHP app's Termux admin tool.
class ExamNode {
  const ExamNode({
    required this.id,
    required this.name,
    required this.parentExamId,
    required this.logoUrl,
    required this.sortOrder,
    required this.types,
  });

  final String id;
  final String name;
  final String? parentExamId;

  /// Admin-uploaded PNG/JPG/WebP (Supabase Storage, public bucket) shown
  /// before the name in the exam/paper list — null means "show the
  /// default icon instead".
  final String? logoUrl;

  final int sortOrder;

  /// Which flow(s) (Mock Test, PYQ) this node shows up under — the
  /// repository's fetch methods already filter by the caller's requested
  /// type, so by the time a screen sees an ExamNode it's implicitly
  /// visible there; this is mainly for the admin tool's own display.
  final List<TestSetType> types;

  factory ExamNode.fromMap(Map<String, dynamic> map) {
    final typesRaw = (map['types'] as List?)?.map((e) => e.toString()).toList();
    return ExamNode(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      parentExamId: map['parent_exam_id'] as String?,
      logoUrl: map['logo_url'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      types: (typesRaw == null || typesRaw.isEmpty)
          ? const [TestSetType.mockTest, TestSetType.pyq]
          : typesRaw.map(TestSetTypeX.fromValue).toList(),
    );
  }
}
