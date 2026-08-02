import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `/users/{uid}/questionProgress/{questionId}` — one document per
/// question the student has ever answered, tracking the revision schedule
/// described in the reference PHP app's README (see
/// `SpacedRepetitionService`).
class QuestionProgress {
  const QuestionProgress({
    required this.questionId,
    this.completedCount = 0,
    required this.dueDate,
    this.lastResult,
    this.lastReviewedAt,
  });

  final String questionId;
  final int completedCount;
  final DateTime dueDate;
  final String? lastResult; // "correct" | "wrong"
  final DateTime? lastReviewedAt;

  factory QuestionProgress.fromMap(
    String questionId,
    Map<String, dynamic> map,
  ) {
    return QuestionProgress(
      questionId: questionId,
      completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastResult: map['lastResult'] as String?,
      lastReviewedAt: (map['lastReviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'completedCount': completedCount,
      'dueDate': Timestamp.fromDate(dueDate),
      'lastResult': lastResult,
      'lastReviewedAt': lastReviewedAt != null
          ? Timestamp.fromDate(lastReviewedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  bool get isDue => !dueDate.isAfter(DateTime.now());
}
