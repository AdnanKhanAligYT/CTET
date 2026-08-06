import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../domain/attempt.dart';

class HistoryRepository {
  HistoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Attempt>> fetchAttempts(String uid) async {
    final rows = await _client
        .from('attempts')
        .select('*, test_sets(name)')
        .eq('user_id', uid)
        .eq('status', 'completed')
        .order('submitted_at', ascending: false);
    return rows.map((row) => Attempt.fromMap(row['id'] as String, row)).toList();
  }
}
