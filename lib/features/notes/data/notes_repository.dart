import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/notes_block.dart';
import '../../../core/models/notes_chapter.dart';

class NotesRepository {
  NotesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<NotesChapter>> fetchChapters(String subject) async {
    final rows = await _client
        .from('notes_chapters')
        .select()
        .eq('subject', subject)
        .order('sort_order');
    return rows.map((row) => NotesChapter.fromMap(row)).toList();
  }

  Future<List<NotesBlock>> fetchBlocks(String chapterId) async {
    final rows = await _client
        .from('notes_blocks')
        .select()
        .eq('chapter_id', chapterId)
        .order('sort_order');
    return rows.map((row) => NotesBlock.fromMap(row)).toList();
  }
}
