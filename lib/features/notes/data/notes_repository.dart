import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/notes_chapter.dart';

class NotesRepository {
  NotesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Each row already carries its own full content (see NotesChapter), so
  // fetching the chapter list is the only round-trip the whole Notes flow
  // needs — NotesContentScreen just renders what's already in hand.
  Future<List<NotesChapter>> fetchChapters(String subject) async {
    final rows = await _client
        .from('notes_chapters')
        .select()
        .eq('subject', subject)
        .order('sort_order');
    return rows.map((row) => NotesChapter.fromMap(row)).toList();
  }
}
