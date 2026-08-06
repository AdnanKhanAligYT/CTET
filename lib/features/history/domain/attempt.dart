/// Mirrors a completed `attempts` row (see `supabase/schema.sql`) — one
/// finished mock test session, either the daily due-today practice test
/// ([testSetName] null) or a named Mock Test / PYQ set ([testSetName],
/// [rank], [participantsCount] set — snapshotted once at finish time by
/// `TestSetRepository.finishAttempt`, never recomputed here).
class Attempt {
  const Attempt({
    required this.id,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.submittedAt,
    required this.testSetName,
    required this.rank,
    required this.participantsCount,
  });

  final String id;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final DateTime submittedAt;
  final String? testSetName;
  final int? rank;
  final int? participantsCount;

  factory Attempt.fromMap(String id, Map<String, dynamic> map) {
    final testSet = map['test_sets'] as Map<String, dynamic>?;
    return Attempt(
      id: id,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
      submittedAt: map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'] as String)
          : DateTime.now(),
      testSetName: testSet?['name'] as String?,
      rank: (map['rank'] as num?)?.toInt(),
      participantsCount: (map['participants_count'] as num?)?.toInt(),
    );
  }
}
