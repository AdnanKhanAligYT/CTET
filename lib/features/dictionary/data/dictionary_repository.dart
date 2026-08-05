import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/dictionary_word.dart';
import '../../../core/models/review_progress.dart';

/// Supabase access for the dictionary feature — same shape as
/// `MockTestRepository` (global content + per-user review progress), just
/// pointed at `dictionary_words` and `dictionary_progress`.
class DictionaryRepository {
  DictionaryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DictionaryWord>> fetchAllWords() async {
    final rows = await _client.from('dictionary_words').select();
    return rows
        .map((row) => DictionaryWord.fromMap(row['id'] as String, row))
        .toList();
  }

  Future<Map<String, ReviewProgress>> fetchProgress(String uid) async {
    final rows = await _client
        .from('dictionary_progress')
        .select()
        .eq('user_id', uid);
    return {
      for (final row in rows)
        row['word_id'] as String: ReviewProgress.fromMap(
          row['word_id'] as String,
          row,
        ),
    };
  }

  Future<void> saveProgress(String uid, ReviewProgress progress) {
    return _client.from('dictionary_progress').upsert({
      'user_id': uid,
      'word_id': progress.itemId,
      ...progress.toMap(),
    }, onConflict: 'user_id,word_id');
  }
}
