import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/user_profile.dart';
import 'core/routing/app_router.dart';
import 'core/services/ad_service.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/application/profile_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Ads never block startup: initialize() itself isn't awaited, so a slow
  // or unreachable ad network only delays ads, not the whole app.
  unawaited(AdService.initialize());
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
