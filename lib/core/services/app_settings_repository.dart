import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Reads the admin-managed `app_settings` key/value table — currently
/// just the exam countdown date, set from the reference PHP app's
/// Exams tab. Read-only from the app, same trust boundary as the
/// exams/test_sets catalog.
class AppSettingsRepository {
  AppSettingsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Null if the admin hasn't set one yet, or the stored value isn't a
  /// parseable date — either way the caller just skips the countdown
  /// reminder rather than showing garbage.
  Future<DateTime?> fetchExamCountdownDate() async {
    final rows = await _client
        .from('app_settings')
        .select('value')
        .eq('key', 'exam_countdown_date')
        .limit(1);
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
