import 'package:flutter_test/flutter_test.dart';
import 'package:ctet_tet_prep/core/models/review_progress.dart';
import 'package:ctet_tet_prep/core/services/spaced_repetition_service.dart';

void main() {
  final service = SpacedRepetitionService();
  final now = DateTime(2026, 1, 1, 10);

  test('first review is due tomorrow', () {
    final result = service.recordAnswer(
      itemId: 'q1',
      current: null,
      wasCorrect: true,
      now: now,
    );
    expect(result.completedCount, 1);
    expect(result.dueDate, now.add(const Duration(days: 1)));
    expect(result.lastResult, 'correct');
  });

  test('second review is due in 2 days', () {
    final first = service.recordAnswer(
      itemId: 'q1',
      current: null,
      wasCorrect: true,
      now: now,
    );
    final second = service.recordAnswer(
      itemId: 'q1',
      current: first,
      wasCorrect: false,
      now: now,
    );
    expect(second.completedCount, 2);
    expect(second.dueDate, now.add(const Duration(days: 2)));
    expect(second.lastResult, 'wrong');
  });

  test('interval caps at 30 days no matter how many times reviewed', () {
    ReviewProgress? progress;
    for (var i = 0; i < 40; i++) {
      progress = service.recordAnswer(
        itemId: 'q1',
        current: progress,
        wasCorrect: true,
        now: now,
      );
    }
    expect(progress!.completedCount, 40);
    expect(progress.dueDate, now.add(const Duration(days: 30)));
  });

  test('a brand-new item (no progress) is always due today', () {
    expect(service.isDueToday(null, now: now), isTrue);
  });

  test('an item due in the future is not due today', () {
    final progress = ReviewProgress(
      itemId: 'q1',
      completedCount: 1,
      dueDate: now.add(const Duration(days: 1)),
    );
    expect(service.isDueToday(progress, now: now), isFalse);
  });

  test('an item due today or earlier is due', () {
    final dueToday = ReviewProgress(
      itemId: 'q1',
      completedCount: 1,
      dueDate: now,
    );
    final overdue = ReviewProgress(
      itemId: 'q2',
      completedCount: 1,
      dueDate: now.subtract(const Duration(days: 5)),
    );
    expect(service.isDueToday(dueToday, now: now), isTrue);
    expect(service.isDueToday(overdue, now: now), isTrue);
  });
}
