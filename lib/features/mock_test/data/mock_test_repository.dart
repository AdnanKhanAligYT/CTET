import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/question.dart';
import '../../../core/models/review_progress.dart';

/// Supabase access for the mock-test feature. Kept as one small repository
/// (rather than spreading raw Postgrest calls through the
/// controller/screens) so the query shape — global `questions` filtered by
/// exam, per-user `question_progress` — stays in one place.
class MockTestRepository {
  MockTestRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Question>> fetchQuestionsForExams(List<String> exams) async {
    if (exams.isEmpty) return const [];
    // exam_tags is tagged generically ("CTET") rather than per-paper —
    // see SyllabusRepository.fetchTopicsForExams for the same reasoning.
    final lookupExams = {
      ...exams,
      for (final e in exams)
        if (e.contains('CTET')) 'CTET',
    }.toList();
    final rows = await _client
        .from('questions')
        .select()
        .overlaps('exam_tags', lookupExams);
    return rows.map((row) => Question.fromMap(row['id'] as String, row)).toList();
  }

  /// Every uploaded question, with no `exam_tags` filtering — used by
  /// Subject Wise Revision. That field is a separate, older tagging
  /// mechanism from the Exam/Test-Set catalog the admin tool's Test Sets
  /// tab actually tags questions into; content added there never gets
  /// `exam_tags` set, so filtering by it here would silently hide
  /// perfectly real, uploaded questions. Subject Wise Revision is meant
  /// to reflect "whatever's been uploaded" anyway, not be scoped to the
  /// student's own exam selection like the due-today practice above.
  Future<List<Question>> fetchAllQuestions() async {
    final rows = await _client.from('questions').select();
    return rows.map((row) => Question.fromMap(row['id'] as String, row)).toList();
  }

  Future<Map<String, ReviewProgress>> fetchProgress(String uid) async {
    final rows = await _client
        .from('question_progress')
        .select()
        .eq('user_id', uid);
    return {
      for (final row in rows)
        row['question_id'] as String: ReviewProgress.fromMap(
          row['question_id'] as String,
          row,
        ),
    };
  }

  Future<void> saveProgress(String uid, ReviewProgress progress) {
    return _client.from('question_progress').upsert({
      'user_id': uid,
      'question_id': progress.itemId,
      ...progress.toMap(),
    }, onConflict: 'user_id,question_id');
  }

  Future<void> saveAttempt({
    required String uid,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required DateTime startedAt,
    required DateTime submittedAt,
  }) {
    return _client.from('attempts').insert({
      'user_id': uid,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
    });
  }
}
