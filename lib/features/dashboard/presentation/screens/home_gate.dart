import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/application/profile_controller.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import 'dashboard_screen.dart';

/// The '/' route. Rather than push a separate route for "profile
/// incomplete", this simply renders the Edit Profile screen in place until
/// the student has a name and at least one exam picked — covers both a
/// fresh signup whose Firestore write is still in flight, and someone who
/// backed out of setup before finishing it.
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
        if (profile == null || !profile.isSetupComplete) {
          return const EditProfileScreen(isFirstTimeSetup: true);
        }
        return DashboardScreen(profile: profile);
      },
    );
  }
}
