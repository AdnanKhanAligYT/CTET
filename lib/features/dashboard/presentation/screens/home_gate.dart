import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import 'dashboard_screen.dart';

/// The '/' route. Rather than push a separate route for "profile
/// incomplete", this simply renders the Edit Profile screen in place until
/// the student has a name and at least one exam picked — covers someone
/// who backed out of the email/phone name-entry step before finishing it.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Something went wrong: $error'))),
      data: (profile) {
        // A brand-new Google sign-in has no `profiles` row yet — unlike
        // email/phone signup, which already creates one (with a name,
        // before ever reaching here — see manual_name_screen/
        // suggested_name_screen). Auto-create a default one (CTET) instead
        // of forcing a setup screen, since Google already gave a
        // name/photo; the student can still change the exam later from
        // Edit Profile.
        if (profile == null) {
          _autoCreateDefaultProfile(ref);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!profile.isSetupComplete) {
          return const EditProfileScreen(isFirstTimeSetup: true);
        }
        _backfillGooglePhotoIfMissing(ref, profile);
        // The FCM token fetched at app-start (main.dart) may have run
        // before Supabase auth restored the session, so nothing got
        // saved then — this re-tries now that we know a profile loaded,
        // which only happens once actually signed in.
        PushNotificationService.onSignedIn();
        return DashboardScreen(profile: profile);
      },
    );
  }
}

bool _creatingDefaultProfile = false;

/// Fire-and-forget: creates the `profiles` row a fresh Google sign-in
/// doesn't have yet, defaulting the exam to CTET so there's no setup
/// screen blocking the student's first look at the app. Guarded by a
/// module-level flag so a rebuild while the row is still being created
/// doesn't fire a second upsert; the stream this screen watches picks up
/// the new row automatically once it's written, no manual navigation
/// needed.
void _autoCreateDefaultProfile(WidgetRef ref) {
  if (_creatingDefaultProfile) return;
  _creatingDefaultProfile = true;
  Future.microtask(() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final metadata = user.userMetadata;
      final googleName = (metadata?['full_name'] as String?)?.trim();
      final fallbackName = user.email?.split('@').first ?? 'Student';
      await ref
          .read(profileControllerProvider.notifier)
          .createInitialProfile(
            displayName: (googleName != null && googleName.isNotEmpty)
                ? googleName
                : fallbackName,
            source: DisplayNameSource.manual,
            exams: const ['CTET'],
          );
    } finally {
      _creatingDefaultProfile = false;
    }
  });
}

/// Best-effort, fire-and-forget: a profile whose setup completed before
/// Google Sign-In existed (or before it captured a photo) never gets a
/// second chance to pick one up, since this is the only screen every
/// session passes through once setup is done. No-ops instantly for anyone
/// who already has a photo, or who isn't signed in via Google.
void _backfillGooglePhotoIfMissing(WidgetRef ref, UserProfile profile) {
  if (profile.photoURL != null && profile.photoURL!.isNotEmpty) return;
  final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
  final googlePhoto =
      metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?;
  if (googlePhoto == null || googlePhoto.isEmpty) return;
  Future.microtask(() {
    ref
        .read(profileControllerProvider.notifier)
        .updateProfile(profile.copyWith(photoURL: googlePhoto));
  });
}
