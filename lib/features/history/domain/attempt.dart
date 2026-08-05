/// Mirrors an `attempts` row (see `supabase/schema.sql`) — one completed
/// (or stopped-early) mock test session, written by
/// `MockTestRepository.saveAttempt`.
class Attempt {
  const Attempt({
    required this.id,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.submittedAt,
  });

  final String id;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final DateTime submittedAt;

  factory Attempt.fromMap(String id, Map<String, dynamic> map) {
    return Attempt(
      id: id,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
      submittedAt: map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'] as String)
          : DateTime.now(),
    );
  }
}
