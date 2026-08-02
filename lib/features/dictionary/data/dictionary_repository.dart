import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/dictionary_word.dart';
import '../../../core/models/review_progress.dart';

/// Firestore access for the dictionary feature — same shape as
/// `MockTestRepository` (global content + per-user review progress), just
/// pointed at `/dictionaryWords` and `/users/{uid}/dictionaryProgress`.
class DictionaryRepository {
  DictionaryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<DictionaryWord>> fetchAllWords() async {
    final snapshot = await _firestore.collection('dictionaryWords').get();
    return snapshot.docs
        .map((doc) => DictionaryWord.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<Map<String, ReviewProgress>> fetchProgress(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dictionaryProgress')
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: ReviewProgress.fromMap(doc.id, doc.data()),
    };
  }

  Future<void> saveProgress(String uid, ReviewProgress progress) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dictionaryProgress')
        .doc(progress.itemId)
        .set(progress.toMap());
  }
}
