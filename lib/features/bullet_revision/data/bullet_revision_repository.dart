import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../mock_test/data/mock_test_repository.dart';
import '../../mock_test/data/question_dedupe.dart';

/// Picks CDP-only question ids for the Bullet Revision feature — a
/// duration (1/5/10/20/30/60 minutes = that many questions, one per
/// minute) drawn from a per-user rotation that never repeats a question
/// until every CDP question has appeared once, then reshuffles for a
/// fresh cycle. See [pickNextQuestionIds]; the remaining-queue state
/// lives in the `bullet_revision_state` table (migration_bullet_revision.sql).
class BulletRevisionRepository {
  BulletRevisionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const subject = 'CDP';

  /// Returns up to [count] CDP question ids for the next test, in play
  /// order, and persists what's left of the rotation for next time.
  /// Returns fewer than [count] only if the whole CDP pool itself has
  /// fewer questions than that — never by repeating one within this
  /// batch.
  Future<List<String>> pickNextQuestionIds(String uid, int count) async {
    final questions = dedupeByText(
      await MockTestRepository(client: _client).fetchQuestionsForSubject(subject),
    );
    final pool = questions.map((q) => q.id).toList();
    if (pool.isEmpty) return const [];

    final target = count > pool.length ? pool.length : count;
    var remaining = await _loadRemainingQueue(uid, pool);

    final picked = <String>[];
    while (picked.length < target) {
      if (remaining.isEmpty) {
        // Cycle complete (or this is the very first run) — start a fresh
        // shuffled pass through the whole pool.
        remaining = [...pool]..shuffle();
      }
      picked.add(remaining.removeAt(0));
    }

    await _saveRemainingQueue(uid, remaining);
    return picked;
  }

  /// The ids still left from the current cycle, dropped down to whatever
  /// still exists in [pool] — a question removed from the bank since the
  /// last run shouldn't leave a dangling id in the queue forever.
  Future<List<String>> _loadRemainingQueue(String uid, List<String> pool) async {
    final row = await _client
        .from('bullet_revision_state')
        .select('remaining_question_ids')
        .eq('user_id', uid)
        .maybeSingle();
    final stored =
        (row?['remaining_question_ids'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final poolSet = pool.toSet();
    return stored.where(poolSet.contains).toList();
  }

  Future<void> _saveRemainingQueue(String uid, List<String> remaining) async {
    await _client.from('bullet_revision_state').upsert({
      'user_id': uid,
      'remaining_question_ids': remaining,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Open counts (all students combined) for every duration button
  /// already tapped at least once — a duration with no row yet has 0.
  Future<Map<int, int>> fetchDurationOpenCounts() async {
    final rows = await _client
        .from('bullet_revision_duration_open_counts')
        .select('duration_minutes, open_count');
    return {
      for (final row in rows)
        (row['duration_minutes'] as num).toInt():
            (row['open_count'] as num).toInt(),
    };
  }

  /// Fire-and-forget: bumps [durationMinutes]'s open count by 1 — same
  /// swallow-errors, never-await stance as the other open-count
  /// recorders, so a missed count never blocks starting the test.
  void recordDurationOpened(int durationMinutes) {
    unawaited(
      _client
          .rpc(
            'increment_bullet_revision_duration_open_count',
            params: {'p_duration_minutes': durationMinutes},
          )
          .catchError((_) {}),
    );
  }
}
