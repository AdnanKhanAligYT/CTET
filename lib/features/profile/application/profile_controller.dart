import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/models/user_profile.dart';
import '../../auth/application/auth_controller.dart';

final _client = Supabase.instance.client;

/// Live Postgres stream of the signed-in student's `profiles` row. `null`
/// while there's no signed-in user, or once briefly right after signup
/// before the profile row has been created.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return _client.from('profiles').stream(primaryKey: ['id']).eq('id', user.id).map((
    rows,
  ) {
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(user.id, rows.first);
  });
});

final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<void>>(
      ProfileController.new,
    );

/// Creates/updates the student's `profiles` row. Kept separate from
/// AuthController so a database write failure never gets confused with an
/// auth failure in the UI.
class ProfileController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  User? get _currentUser => _client.auth.currentUser;

  /// Called right after a brand-new signup (either method) to create the
  /// initial `profiles` row.
  Future<void> createInitialProfile({
    required String displayName,
    required DisplayNameSource source,
    List<String> exams = const [],
  }) async {
    final user = _currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.auth.updateUser(
        UserAttributes(data: {'display_name': displayName}),
      );
      final profile = UserProfile(
        uid: user.id,
        displayName: displayName,
        displayNameSource: source,
        email: user.email,
        phone: user.phone,
        designation: 'Student',
        exams: exams,
        passwordSet: user.appMetadata['provider'] == 'email',
      );
      await _client.from('profiles').upsert(profile.toMap());
    });
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.from('profiles').upsert(profile.toMap());
    });
  }

  Future<void> markPasswordSet() async {
    final user = _currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({
          'password_set': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);
  }

  /// Play Store policy requires an in-app way to delete one's account.
  /// Actually deleting the `auth.users` row (which cascades to `profiles`
  /// and every per-student table via `on delete cascade` — see
  /// `supabase/schema.sql`) needs the `service_role` key, which must never
  /// ship inside the app, so this calls the `delete-account` Edge Function
  /// instead (see `supabase/functions/delete-account`).
  /// Throws on failure (e.g. the Edge Function isn't deployed yet) instead
  /// of the old silent-swallow — `AsyncValue.guard` alone captured the
  /// error into `state` but nothing read it, so the Delete Account button
  /// used to just do nothing with zero feedback. Callers should show
  /// whatever this throws to the student. signOut() only ever runs after
  /// the account is actually gone.
  Future<void> deleteAccount() async {
    if (_currentUser == null) return;
    state = const AsyncValue.loading();
    try {
      final response = await _client.functions.invoke('delete-account');
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw StateError(data['error'].toString());
      }
      await _client.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
