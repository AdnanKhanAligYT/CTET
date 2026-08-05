import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/models/user_profile.dart';
import 'core/routing/app_router.dart';
import 'core/services/ad_service.dart';
import 'core/services/notification_service.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/application/profile_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  // Ads and notification setup never block startup: neither call is
  // awaited, so a slow/unreachable network only delays those features,
  // not the whole app.
  unawaited(AdService.initialize());
  unawaited(NotificationService.initialize());
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
