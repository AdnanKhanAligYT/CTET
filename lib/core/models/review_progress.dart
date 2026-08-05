/// One row per reviewable item (a mock-test question, a dictionary
/// word, ...) a student has ever answered, tracking the revision schedule
/// described in the reference PHP app's README — see
/// `SpacedRepetitionService`. Shared by every feature with a "due today"
/// review loop (mock test: `question_progress`, dictionary:
/// `dictionary_progress` — see `supabase/schema.sql`) so the scheduling
/// logic and its tests live in exactly one place.
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
      completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : DateTime.now(),
      lastResult: map['last_result'] as String?,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'completed_count': completedCount,
      'due_date': dueDate.toIso8601String(),
      'last_result': lastResult,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  bool get isDue => !dueDate.isAfter(DateTime.now());
}
