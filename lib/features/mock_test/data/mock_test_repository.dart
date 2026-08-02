import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/question.dart';
import '../domain/question_progress.dart';

/// Firestore access for the mock-test feature. Kept as one small
/// repository (rather than spreading raw Firestore calls through the
/// controller/screens) so the query shape — global `/questions` filtered
/// by exam, per-user `/questionProgress` — stays in one place.
class MockTestRepository {
  MockTestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Firestore's `array-contains-any` allows at most 10 values; the exam
  /// catalog is small enough today that this never matters, but the cap
  /// is enforced here so a future larger catalog fails loudly instead of
  /// silently dropping exams.
  Future<List<Question>> fetchQuestionsForExams(List<String> exams) async {
    if (exams.isEmpty) return const [];
    assert(
      exams.length <= 10,
      'Firestore array-contains-any supports at most 10 values',
    );
    final snapshot = await _firestore
        .collection('questions')
        .where('examTags', arrayContainsAny: exams)
        .get();
    return snapshot.docs
        .map((doc) => Question.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Map<String, QuestionProgress>> fetchProgress(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('questionProgress')
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: QuestionProgress.fromMap(doc.id, doc.data()),
    };
  }

  Future<void> saveProgress(String uid, QuestionProgress progress) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('questionProgress')
        .doc(progress.questionId)
        .set(progress.toMap());
  }

  Future<void> saveAttempt({
    required String uid,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required DateTime startedAt,
    required DateTime submittedAt,
  }) {
    return _firestore.collection('users').doc(uid).collection('attempts').add({
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'startedAt': Timestamp.fromDate(startedAt),
      'submittedAt': Timestamp.fromDate(submittedAt),
    });
  }
}
