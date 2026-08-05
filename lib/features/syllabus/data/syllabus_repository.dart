import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/syllabus_topic.dart';
import '../domain/topic_status.dart';

class SyllabusRepository {
  SyllabusRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SyllabusTopic>> fetchTopicsForExams(List<String> exams) async {
    if (exams.isEmpty) return const [];
    final rows = await _client
        .from('syllabus_topics')
        .select()
        .inFilter('exam', exams);
    final topics =
        rows
            .map((row) => SyllabusTopic.fromMap(row['id'] as String, row))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return topics;
  }

  Future<Map<String, TopicStatus>> fetchProgress(String uid) async {
    final rows = await _client
        .from('syllabus_progress')
        .select()
        .eq('user_id', uid);
    return {
      for (final row in rows)
        row['topic_id'] as String: topicStatusFromString(
          row['status'] as String?,
        ),
    };
  }

  Future<void> setStatus(String uid, String topicId, TopicStatus status) {
    final data = <String, dynamic>{
      'user_id': uid,
      'topic_id': topicId,
      'status': status.toStorageString(),
    };
    if (status == TopicStatus.done) {
      data['completed_at'] = DateTime.now().toIso8601String();
    }
    return _client
        .from('syllabus_progress')
        .upsert(data, onConflict: 'user_id,topic_id');
  }
}
