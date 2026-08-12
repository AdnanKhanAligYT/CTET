import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/mock_test_session.dart';

/// On-device-only persistence for an in-progress Mock Test attempt — the
/// whole point is that this data never reaches Supabase (see
/// MockTestSession's doc comment), so a resume only works on the same
/// device/app-install where the test was started. One JSON blob per
/// (student, test set) pair, keyed so switching accounts on a shared
/// device can't leak/overwrite another student's in-progress attempt.
class MockTestLocalStore {
  static String _key(String uid, String testSetId) =>
      'mock_test_session::$uid::$testSetId';

  Future<void> save(String uid, MockTestSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(uid, session.testSetId),
      jsonEncode(session.toJson()),
    );
  }

  Future<MockTestSession?> load(String uid, String testSetId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid, testSetId));
    if (raw == null) return null;
    try {
      return MockTestSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt/old-shape entry — treat as "no session" rather than crash.
      return null;
    }
  }

  Future<void> clear(String uid, String testSetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid, testSetId));
  }
}
