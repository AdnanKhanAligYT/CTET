import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/timetable_block.dart';

class TimetableRepository {
  TimetableRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TimetableBlock>> fetchBlocks(String uid) async {
    final rows = await _client
        .from('timetable_blocks')
        .select()
        .eq('user_id', uid);
    return rows
        .map((row) => TimetableBlock.fromMap(row['id'] as String, row))
        .toList();
  }

  Future<void> addBlock(String uid, TimetableBlock block) {
    return _client.from('timetable_blocks').insert({
      'user_id': uid,
      ...block.toMap(),
    });
  }

  Future<void> setDone(String uid, String blockId, bool done) {
    return _client
        .from('timetable_blocks')
        .update({'done': done})
        .eq('user_id', uid)
        .eq('id', blockId);
  }

  Future<void> deleteBlock(String uid, String blockId) {
    return _client
        .from('timetable_blocks')
        .delete()
        .eq('user_id', uid)
        .eq('id', blockId);
  }
}
