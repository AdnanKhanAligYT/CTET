import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/timetable_block.dart';

class TimetableRepository {
  TimetableRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('timetable');

  Future<List<TimetableBlock>> fetchBlocks(String uid) async {
    final snapshot = await _collection(uid).get();
    return snapshot.docs
        .map((doc) => TimetableBlock.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> addBlock(String uid, TimetableBlock block) {
    return _collection(uid).add(block.toMap());
  }

  Future<void> setDone(String uid, String blockId, bool done) {
    return _collection(uid).doc(blockId).update({'done': done});
  }

  Future<void> deleteBlock(String uid, String blockId) {
    return _collection(uid).doc(blockId).delete();
  }
}
