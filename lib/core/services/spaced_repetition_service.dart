import '../models/review_progress.dart';

/// Ports the revision scheduling described in the reference PHP app's
/// README verbatim: every time an item (question, dictionary word, ...)
/// is reviewed its `completedCount` goes up by one, and the next due date
/// becomes `completedCount` days from now, capped at 30 — 1st review due
/// tomorrow, 2nd due in 2 days, 3rd in 3 days, and so on up to a month.
/// Deliberately simple (not full SM-2) to match the original app's
/// actual behaviour rather than substituting a different algorithm. Used
/// by both the mock-test and dictionary features, which share this exact
/// due-today review loop.
class SpacedRepetitionService {
  const SpacedRepetitionService({this.maxIntervalDays = 30});

  final int maxIntervalDays;

  /// Computes the updated progress after reviewing [itemId]. [current] is
  /// null the first time the student ever sees this item.
  ReviewProgress recordAnswer({
    required String itemId,
    required ReviewProgress? current,
    required bool wasCorrect,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final nextCompletedCount = (current?.completedCount ?? 0) + 1;
    final intervalDays = nextCompletedCount > maxIntervalDays
        ? maxIntervalDays
        : nextCompletedCount;

    return ReviewProgress(
      itemId: itemId,
      completedCount: nextCompletedCount,
      dueDate: effectiveNow.add(Duration(days: intervalDays)),
      lastResult: wasCorrect ? 'correct' : 'wrong',
      lastReviewedAt: effectiveNow,
    );
  }

  /// An item is shown today if it's brand new (no progress yet) or its
  /// due date has arrived.
  bool isDueToday(ReviewProgress? progress, {DateTime? now}) {
    if (progress == null) return true;
    final effectiveNow = now ?? DateTime.now();
    return !progress.dueDate.isAfter(effectiveNow);
  }
}
