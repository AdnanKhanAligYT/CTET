import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/exam_node.dart';
import '../../../core/models/test_set.dart';

/// Reads the admin-managed exam/paper catalog (`exams` table) that drives
/// Mock Test and Previous Year Questions navigation — top-level rows
/// (parent_exam_id null) are exams like "CTET", their children are papers
/// like "CTET Paper 1" / "CTET Paper 2", any number of levels deep.
/// Entirely read-only from the app: add/remove/reorder happens from
/// outside it (the reference PHP app's Termux admin tool, using the
/// Supabase service key).
class ExamCatalogRepository {
  ExamCatalogRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Every fetch here is scoped to [type] via `.contains('types', ...)` —
  /// a node the admin restricted to just Mock Test (or just PYQ) simply
  /// doesn't come back when browsing the other flow, same as how
  /// TestSetRepository.fetchTestSets() already filters test_sets.types.
  Future<List<ExamNode>> fetchTopLevelExams(TestSetType type) async {
    final rows = await _client
        .from('exams')
        .select()
        .eq('active', true)
        .filter('parent_exam_id', 'is', null)
        .contains('types', [type.value])
        .order('sort_order');
    return rows.map((row) => ExamNode.fromMap(row)).toList();
  }

  Future<List<ExamNode>> fetchPapers(
    String parentExamId,
    TestSetType type,
  ) async {
    final rows = await _client
        .from('exams')
        .select()
        .eq('active', true)
        .eq('parent_exam_id', parentExamId)
        .contains('types', [type.value])
        .order('sort_order');
    return rows.map((row) => ExamNode.fromMap(row)).toList();
  }
}
