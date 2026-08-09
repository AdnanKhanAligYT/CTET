import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/exam_node.dart';

/// Reads the admin-managed exam/paper catalog (`exams` table) that drives
/// Mock Test and Previous Year Questions navigation — top-level rows
/// (parent_exam_id null) are exams like "CTET", their children are papers
/// like "CTET Paper 1" / "CTET Paper 2". Entirely read-only from the app:
/// add/remove/reorder happens from outside it (the reference PHP app's
/// Termux admin tool, using the Supabase service key).
class ExamCatalogRepository {
  ExamCatalogRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ExamNode>> fetchTopLevelExams() async {
    final rows = await _client
        .from('exams')
        .select()
        .eq('active', true)
        .filter('parent_exam_id', 'is', null)
        .order('sort_order');
    return rows.map((row) => ExamNode.fromMap(row)).toList();
  }

  Future<List<ExamNode>> fetchPapers(String parentExamId) async {
    final rows = await _client
        .from('exams')
        .select()
        .eq('active', true)
        .eq('parent_exam_id', parentExamId)
        .order('sort_order');
    return rows.map((row) => ExamNode.fromMap(row)).toList();
  }

  /// The one exams row currently marked as the dashboard shortcut, if any
  /// (a partial unique index guarantees at most one).
  Future<ExamNode?> fetchShortcut() async {
    final rows = await _client
        .from('exams')
        .select()
        .eq('active', true)
        .eq('is_shortcut', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return ExamNode.fromMap(rows.first);
  }
}
