import 'package:flutter_test/flutter_test.dart';
import 'package:ctet_tet_prep/features/mock_test/domain/question_progress.dart';
import 'package:ctet_tet_prep/features/mock_test/domain/spaced_repetition_service.dart';

void main() {
  final service = SpacedRepetitionService();
  final now = DateTime(2026, 1, 1, 10);

  test('first answer is due tomorrow', () {
    final result = service.recordAnswer(
      questionId: 'q1',
      current: null,
      wasCorrect: true,
      now: now,
    );
    expect(result.completedCount, 1);
    expect(result.dueDate, now.add(const Duration(days: 1)));
    expect(result.lastResult, 'correct');
  });

  test('second answer is due in 2 days', () {
    final first = service.recordAnswer(
      questionId: 'q1',
      current: null,
      wasCorrect: true,
      now: now,
    );
    final second = service.recordAnswer(
      questionId: 'q1',
      current: first,
      wasCorrect: false,
      now: now,
    );
    expect(second.completedCount, 2);
    expect(second.dueDate, now.add(const Duration(days: 2)));
    expect(second.lastResult, 'wrong');
  });

  test('interval caps at 30 days no matter how many times answered', () {
    QuestionProgress? progress;
    for (var i = 0; i < 40; i++) {
      progress = service.recordAnswer(
        questionId: 'q1',
        current: progress,
        wasCorrect: true,
        now: now,
      );
    }
    expect(progress!.completedCount, 40);
    expect(progress.dueDate, now.add(const Duration(days: 30)));
  });

  test('a brand-new question (no progress) is always due today', () {
    expect(service.isDueToday(null, now: now), isTrue);
  });

  test('a question due in the future is not due today', () {
    final progress = QuestionProgress(
      questionId: 'q1',
      completedCount: 1,
      dueDate: now.add(const Duration(days: 1)),
    );
    expect(service.isDueToday(progress, now: now), isFalse);
  });

  test('a question due today or earlier is due', () {
    final dueToday = QuestionProgress(
      questionId: 'q1',
      completedCount: 1,
      dueDate: now,
    );
    final overdue = QuestionProgress(
      questionId: 'q2',
      completedCount: 1,
      dueDate: now.subtract(const Duration(days: 5)),
    );
    expect(service.isDueToday(dueToday, now: now), isTrue);
    expect(service.isDueToday(overdue, now: now), isTrue);
  });
}
