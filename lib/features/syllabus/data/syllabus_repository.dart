import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/syllabus_topic.dart';
import '../domain/topic_status.dart';

class SyllabusRepository {
  SyllabusRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SyllabusTopic>> fetchTopicsForExams(List<String> exams) async {
    if (exams.isEmpty) return const [];
    // Syllabus content is tagged generically ("CTET") rather than
    // per-paper, since Paper 1/Paper 2 share most of the syllabus — a
    // profile exam of "CTET Paper 1"/"CTET Paper 2" still needs to match
    // that shared "CTET" tag.
    final lookupExams = {
      ...exams,
      for (final e in exams)
        if (e.contains('CTET')) 'CTET',
    }.toList();
    final rows = await _client
        .from('syllabus_topics')
        .select()
        .inFilter('exam', lookupExams);
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

  /// The marks-distribution table shown above the topic list (e.g. "CTET
  /// Paper 1" -> Child Development 30, Mathematics 30, ...). Admin-managed,
  /// one row per paper — null when nothing's been added for [exam] yet, so
  /// the screen can just skip rendering the table instead of erroring.
  Future<List<List<String>>?> fetchMarksTable(String exam) async {
    final rows = await _client
        .from('syllabus_marks_distribution')
        .select()
        .eq('exam', exam)
        .limit(1);
    if (rows.isEmpty) return null;
    final raw = rows.first['table_data'] as List?;
    if (raw == null) return null;
    return raw
        .map((row) => (row as List).map((cell) => cell.toString()).toList())
        .toList();
  }
}
