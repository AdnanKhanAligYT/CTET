import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/attempt.dart';

class HistoryRepository {
  HistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Attempt>> fetchAttempts(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .orderBy('submittedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Attempt.fromMap(doc.id, doc.data()))
        .toList();
  }
}
