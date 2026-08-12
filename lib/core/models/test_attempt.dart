/// Mirrors an `attempts` row when it belongs to a named test set
/// ([testSetId] not null) — see `supabase/schema.sql`. Unlike the plain
/// daily due-today attempts (`Attempt` in the History feature), these can
/// be `in_progress` (paused mid-test, resumable) and carry a snapshot of
/// exactly where the student left off.
enum TestAttemptStatus { inProgress, completed, abandoned }

TestAttemptStatus _statusFromValue(String? value) {
  switch (value) {
    case 'in_progress':
      return TestAttemptStatus.inProgress;
    case 'abandoned':
      return TestAttemptStatus.abandoned;
    default:
      return TestAttemptStatus.completed;
  }
}

class TestAttempt {
  const TestAttempt({
    required this.id,
    required this.testSetId,
    required this.status,
    required this.currentSubjectIndex,
    required this.answers,
    required this.elapsedSeconds,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.rank,
    required this.participantsCount,
    this.percentile,
  });

  final String id;
  final String testSetId;
  final TestAttemptStatus status;

  /// Index into the test set's `subjects` list — which subject tab is
  /// active right now.
  final int currentSubjectIndex;

  /// question_id -> selected option index, for every question answered so
  /// far in this attempt.
  final Map<String, int> answers;

  final int elapsedSeconds;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;

  /// Set only once [status] is completed — this attempt's position among
  /// everyone who has completed this test set, and how many that is.
  final int? rank;
  final int? participantsCount;

  /// Percentage of other completed attempts on the same test set this
  /// attempt outscored — set alongside [rank] at submit time (see
  /// supabase/migration_test_set_percentile.sql), never recomputed later.
  final double? percentile;

  factory TestAttempt.fromMap(String id, Map<String, dynamic> map) {
    final rawAnswers = (map['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TestAttempt(
      id: id,
      testSetId: map['test_set_id'] as String,
      status: _statusFromValue(map['status'] as String?),
      currentSubjectIndex: (map['current_subject_index'] as num?)?.toInt() ?? 0,
      answers: rawAnswers.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      elapsedSeconds: (map['elapsed_seconds'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      rank: (map['rank'] as num?)?.toInt(),
      participantsCount: (map['participants_count'] as num?)?.toInt(),
      percentile: (map['percentile'] as num?)?.toDouble(),
    );
  }
}
