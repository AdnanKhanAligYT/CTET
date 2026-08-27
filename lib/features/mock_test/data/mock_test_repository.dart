import 'dart:async';

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
    final rows = await _fetchAllRows(
      (from, to) => _client
          .from('questions')
          .select()
          .overlaps('exam_tags', lookupExams)
          .range(from, to),
    );
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
    final rows = await _fetchAllRows(
      (from, to) => _client.from('questions').select().range(from, to),
    );
    return rows.map((row) => Question.fromMap(row['id'] as String, row)).toList();
  }

  /// Lightweight counterpart to [fetchAllQuestions] for screens that only
  /// need per-subject counts (Subject Wise Revision's list) — selects just
  /// `subject` and `text` instead of every column. `options`, `explanations`,
  /// `table` and `image_urls` make up most of each row's bytes and were
  /// being pulled over the wire (and JSON-decoded into full Question
  /// objects) on every open of that screen just to be discarded a moment
  /// later, which made it visibly slow to open once the question bank grew.
  Future<List<({String subject, String text})>>
  fetchAllQuestionSubjectsAndText() async {
    final rows = await _fetchAllRows(
      (from, to) =>
          _client.from('questions').select('subject, text').range(from, to),
    );
    return rows
        .map(
          (row) => (
            subject: row['subject'] as String? ?? '',
            text: row['text'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Supabase's PostgREST caps every response at a fixed max-rows (1000 by
  /// default) no matter how many rows actually match — it silently returns
  /// a truncated page instead of erroring, and with no ORDER BY on these
  /// queries *which* 1000 rows come back isn't even stable between calls.
  /// That's exactly what was showing up as random-looking subject counts
  /// on Subject Wise Revision once the question bank passed 1000 rows.
  /// Pages through with .range() so nothing gets silently dropped. Takes a
  /// (from, to) callback rather than a pre-built query object so it works
  /// with whatever filters the caller already chained on.
  Future<List<Map<String, dynamic>>> _fetchAllRows(
    dynamic Function(int from, int to) queryPage,
  ) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final List<dynamic> page = await queryPage(offset, offset + pageSize - 1);
      all.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  /// Same "ignore exam_tags" reasoning as [fetchAllQuestions], but filtered
  /// server-side to one subject — Subject Wise Revision's block picker and
  /// the actual test screen only ever need one subject at a time, so there
  /// is no reason to pull every other subject's questions over the wire
  /// just to immediately discard them client-side.
  Future<List<Question>> fetchQuestionsForSubject(String subject) async {
    final rows = await _fetchAllRows(
      (from, to) => _client
          .from('questions')
          .select()
          .eq('subject', subject)
          .range(from, to),
    );
    return rows.map((row) => Question.fromMap(row['id'] as String, row)).toList();
  }

  /// Fetches exactly these questions, in the same order as [ids] — for a
  /// caller (Bullet Revision) that has already decided which specific
  /// questions to run rather than deriving them from a subject/exam
  /// filter here.
  Future<List<Question>> fetchQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('questions').select().inFilter('id', ids);
    final byId = {
      for (final row in rows)
        row['id'] as String: Question.fromMap(row['id'] as String, row),
    };
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
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

  /// Open counts for every block already opened at least once under
  /// [subject] — blocks that have never been opened simply have no row
  /// (see migration_test_open_counts.sql), so a missing key here means 0.
  Future<Map<int, int>> fetchSubjectBlockOpenCounts(String subject) async {
    final rows = await _client
        .from('subject_block_open_counts')
        .select('block_index, open_count')
        .eq('subject', subject);
    return {
      for (final row in rows)
        (row['block_index'] as num).toInt(): (row['open_count'] as num).toInt(),
    };
  }

  /// Fire-and-forget: bumps this block's open count by 1 — same
  /// swallow-errors, never-await stance as ExamCatalogRepository's
  /// recordExamOpened, so a missed count never blocks opening the block.
  void recordSubjectBlockOpened(String subject, int blockIndex) {
    unawaited(
      _client
          .rpc(
            'increment_subject_block_open_count',
            params: {'p_subject': subject, 'p_block_index': blockIndex},
          )
          .catchError((_) {}),
    );
  }
}
