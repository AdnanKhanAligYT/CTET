import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/question.dart';
import '../../../core/models/test_attempt.dart';
import '../../../core/models/test_set.dart';

/// Supabase access for named Mock Test / PYQ sets: listing sets under a
/// paper, loading a set's questions in their fixed (non-shuffled) order,
/// and the full resumable-attempt lifecycle (start, autosave progress,
/// finish + rank).
class TestSetRepository {
  TestSetRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TestSet>> fetchTestSets(String examId, TestSetType type) async {
    final rows = await _client
        .from('test_sets')
        .select()
        .eq('exam_id', examId)
        .eq('type', type.value)
        .eq('active', true)
        .order('sort_order');
    return rows.map((row) => TestSet.fromMap(row)).toList();
  }

  /// Questions in this set's fixed order (by `position`, then `question_id`
  /// as a tie-break) — never shuffled, since a resumed attempt's "next
  /// question in this subject" is derived by walking this same order and
  /// skipping already-answered ones.
  Future<List<Question>> fetchQuestions(String setId) async {
    final rows = await _client
        .from('test_set_questions')
        .select('question_id, questions(*)')
        .eq('set_id', setId)
        .order('position')
        .order('question_id');
    return rows
        .map(
          (row) => Question.fromMap(
            row['question_id'] as String,
            row['questions'] as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// The one in-progress attempt (if any) this student has for [setId] —
  /// at most one can exist, enforced by a partial unique index in the
  /// schema.
  Future<TestAttempt?> fetchInProgressAttempt(String uid, String setId) async {
    final rows = await _client
        .from('attempts')
        .select()
        .eq('user_id', uid)
        .eq('test_set_id', setId)
        .eq('status', 'in_progress')
        .limit(1);
    if (rows.isEmpty) return null;
    return TestAttempt.fromMap(rows.first['id'] as String, rows.first);
  }

  Future<TestAttempt> startAttempt({
    required String uid,
    required String setId,
    required int totalQuestions,
  }) async {
    final row = await _client
        .from('attempts')
        .insert({
          'user_id': uid,
          'test_set_id': setId,
          'status': 'in_progress',
          'current_subject_index': 0,
          'answers': <String, dynamic>{},
          'elapsed_seconds': 0,
          'total_questions': totalQuestions,
          'correct_count': 0,
          'wrong_count': 0,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return TestAttempt.fromMap(row['id'] as String, row);
  }

  /// A student choosing "Naya Start karo" over an existing in_progress
  /// attempt abandons it first — the unique-in-progress index means a
  /// fresh attempt can't be started otherwise. Abandoned attempts are
  /// excluded from History and from rank/participant counts.
  Future<void> abandonAttempt(String attemptId) {
    return _client
        .from('attempts')
        .update({'status': 'abandoned'})
        .eq('id', attemptId);
  }

  /// Autosave — called after every answer and periodically while the
  /// timer runs, so a killed app or closed screen loses nothing.
  Future<void> saveProgress({
    required String attemptId,
    required int currentSubjectIndex,
    required Map<String, int> answers,
    required int elapsedSeconds,
    required int correctCount,
    required int wrongCount,
  }) {
    return _client
        .from('attempts')
        .update({
          'current_subject_index': currentSubjectIndex,
          'answers': answers,
          'elapsed_seconds': elapsedSeconds,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
        })
        .eq('id', attemptId);
  }

  /// Marks the attempt completed, then ranks it against every other
  /// completed attempt on the same set via the `compute_test_set_rank`
  /// RPC (SECURITY DEFINER — keeps other students' individual scores
  /// private, only the aggregate rank/participant count comes back), and
  /// stores both on the row so History can show them without recomputing.
  Future<TestAttempt> finishAttempt({
    required String attemptId,
    required String setId,
    required int elapsedSeconds,
    required int correctCount,
    required int wrongCount,
  }) async {
    await _client
        .from('attempts')
        .update({
          'status': 'completed',
          'elapsed_seconds': elapsedSeconds,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', attemptId);

    final rankRows =
        await _client.rpc(
              'compute_test_set_rank',
              params: {
                'p_test_set_id': setId,
                'p_correct_count': correctCount,
                'p_elapsed_seconds': elapsedSeconds,
              },
            )
            as List;
    final rankRow = rankRows.first as Map<String, dynamic>;

    final row = await _client
        .from('attempts')
        .update({
          'rank': rankRow['rank'],
          'participants_count': rankRow['participants'],
        })
        .eq('id', attemptId)
        .select()
        .single();
    return TestAttempt.fromMap(row['id'] as String, row);
  }
}
