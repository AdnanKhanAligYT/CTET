import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `/users/{uid}/attempts/{id}` — one completed (or stopped-early)
/// mock test session, written by `MockTestRepository.saveAttempt`.
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
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrongCount'] as num?)?.toInt() ?? 0,
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
