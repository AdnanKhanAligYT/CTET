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
  ///
  /// [allowedNames], when given and non-empty, additionally restricts the
  /// list to exams whose name is in that set — used to scope Mock
  /// Test/PYQ to the student's own exam selection (ExamListScreen passes
  /// their profile's `exams`) rather than showing the whole catalog to
  /// everyone regardless of what they're actually preparing for.
  Future<List<ExamNode>> fetchTopLevelExams(
    TestSetType type, {
    List<String>? allowedNames,
  }) async {
    var query = _client
        .from('exams')
        .select()
        .eq('active', true)
        .filter('parent_exam_id', 'is', null)
        .contains('types', [type.value]);
    if (allowedNames != null && allowedNames.isNotEmpty) {
      query = query.inFilter('name', allowedNames);
    }
    final rows = await query.order('sort_order');
    return rows.map((row) => ExamNode.fromMap(row)).toList();
  }

  /// Distinct top-level exam names (e.g. "CTET", "UPTET") straight from
  /// the admin-managed catalog — backs the student's exam-selection
  /// picker in Edit Profile so the choices offered always match what
  /// content actually exists, instead of a hardcoded list that can drift
  /// out of sync with it. Not scoped to Mock Test vs PYQ `type` since a
  /// student's exam selection applies to both.
  Future<List<String>> fetchTopLevelExamNames() async {
    final rows = await _client
        .from('exams')
        .select('name')
        .eq('active', true)
        .filter('parent_exam_id', 'is', null)
        .order('sort_order');
    return rows.map((row) => row['name'] as String).toList();
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
