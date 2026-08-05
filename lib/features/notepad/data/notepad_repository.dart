import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/note.dart';

class NotepadRepository {
  NotepadRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Note>> fetchNotes(String uid) async {
    final rows = await _client.from('notes').select().eq('user_id', uid);
    final notes = rows
        .map((row) => Note.fromMap(row['id'] as String, row))
        .toList();
    notes.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aTime = a.updatedAt ?? DateTime(0);
      final bTime = b.updatedAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return notes;
  }

  Future<String> createNote(String uid, Note note) async {
    final row = await _client
        .from('notes')
        .insert({'user_id': uid, ...note.toMap()})
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> updateNote(String uid, Note note) {
    return _client
        .from('notes')
        .update(note.toMap())
        .eq('user_id', uid)
        .eq('id', note.id);
  }

  Future<void> deleteNote(String uid, String noteId) {
    return _client
        .from('notes')
        .delete()
        .eq('user_id', uid)
        .eq('id', noteId);
  }
}
