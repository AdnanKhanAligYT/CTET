import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/syllabus_topic.dart';
import '../domain/topic_status.dart';

class SyllabusRepository {
  SyllabusRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SyllabusTopic>> fetchTopicsForExams(List<String> exams) async {
    if (exams.isEmpty) return const [];
    assert(exams.length <= 10, 'Firestore whereIn supports at most 10 values');
    final snapshot = await _firestore
        .collection('syllabusTopics')
        .where('exam', whereIn: exams)
        .get();
    final topics =
        snapshot.docs
            .map((doc) => SyllabusTopic.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return topics;
  }

  Future<Map<String, TopicStatus>> fetchProgress(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('syllabusProgress')
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: topicStatusFromString(doc.data()['status'] as String?),
    };
  }

  Future<void> setStatus(String uid, String topicId, TopicStatus status) {
    final data = <String, dynamic>{'status': status.toStorageString()};
    if (status == TopicStatus.done) {
      data['completedAt'] = FieldValue.serverTimestamp();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('syllabusProgress')
        .doc(topicId)
        .set(data, SetOptions(merge: true));
  }
}
