import 'package:cloud_firestore/cloud_firestore.dart';

/// One document per reviewable item (a mock-test question, a dictionary
/// word, ...) a student has ever answered, tracking the revision schedule
/// described in the reference PHP app's README — see
/// `SpacedRepetitionService`. Shared by every feature with a "due today"
/// review loop (mock test: `/users/{uid}/questionProgress`, dictionary:
/// `/users/{uid}/dictionaryProgress`) so the scheduling logic and its
/// tests live in exactly one place.
class ReviewProgress {
  const ReviewProgress({
    required this.itemId,
    this.completedCount = 0,
    required this.dueDate,
    this.lastResult,
    this.lastReviewedAt,
  });

  final String itemId;
  final int completedCount;
  final DateTime dueDate;
  final String? lastResult; // "correct" | "wrong"
  final DateTime? lastReviewedAt;

  factory ReviewProgress.fromMap(String itemId, Map<String, dynamic> map) {
    return ReviewProgress(
      itemId: itemId,
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
