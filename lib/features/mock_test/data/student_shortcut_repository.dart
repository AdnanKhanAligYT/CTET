import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/exam_node.dart';
import '../../../core/models/test_set.dart';

/// A student's shortcut folder plus which flow (Mock Test vs PYQ) it was
/// set from — the same leaf node can hold test sets of both types, so
/// re-opening the shortcut needs to know which list to show.
class StudentShortcut {
  const StudentShortcut({required this.node, required this.type});

  final ExamNode node;
  final TestSetType type;
}

/// Per-student "shortcut" folder — unlike ExamCatalogRepository above
/// (admin-managed, read-only from the app), a student sets and clears
/// this themselves from a leaf node's own screen (TestSetListScreen's
/// star icon). `user_id` is the primary key on student_shortcuts, so
/// exactly one row exists per student — setting a new shortcut always
/// replaces whichever one they had before, no separate clear-old step
/// needed.
class StudentShortcutRepository {
  StudentShortcutRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// [uid]'s current shortcut, if any.
  Future<StudentShortcut?> fetchMyShortcut(String uid) async {
    final rows = await _client
        .from('student_shortcuts')
        .select('type, exam_id, exams(*)')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final examMap = row['exams'] as Map<String, dynamic>?;
    if (examMap == null) return null;
    return StudentShortcut(
      node: ExamNode.fromMap(examMap),
      type: TestSetTypeX.fromValue(row['type'] as String?),
    );
  }

  Future<void> setMyShortcut(String uid, String examId, TestSetType type) {
    return _client.from('student_shortcuts').upsert({
      'user_id': uid,
      'exam_id': examId,
      'type': type.value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unsetMyShortcut(String uid) {
    return _client.from('student_shortcuts').delete().eq('user_id', uid);
  }
}
