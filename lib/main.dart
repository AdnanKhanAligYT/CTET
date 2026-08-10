import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/models/user_profile.dart';
import 'core/routing/app_router.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/application/profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  var firebaseReady = false;
  try {
    // Used for the Mobile OTP bridge (see
    // core/services/firebase_phone_auth_service.dart) and admin-sent push
    // notifications (see PushNotificationService) — everything else in
    // the app is Supabase. Fails silently until google-services.json is
    // added (see README "Set up Mobile OTP"); Mobile Number sign-in and
    // push notifications just won't work until then, nothing else is
    // affected.
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // ignore
  }
  // Ads and notification setup never block startup: none of these calls
  // are awaited, so a slow/unreachable network only delays those
  // features, not the whole app.
  unawaited(AdService.initialize());
  unawaited(NotificationService.initialize());
  if (firebaseReady) unawaited(PushNotificationService.initialize());
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defaults to following the phone's own light/dark setting (no
    // profile yet, or the student never overrode it in Edit Profile);
    // only becomes an explicit light/dark choice if they picked one.
    final themePreference =
        ref.watch(userProfileProvider).value?.themePreference ??
        AppThemePreference.system;

    return MaterialApp.router(
      title: 'CTET & State TET Prep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePreference.toThemeMode(),
      routerConfig: appRouter,
    );
  }
}
