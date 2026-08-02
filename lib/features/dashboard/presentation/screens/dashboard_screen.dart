import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_profile.dart';
import '../../../auth/application/auth_controller.dart';

/// Placeholder home screen for Phase 1 (foundation: auth + profile). The
/// real dashboard — streaks, due-today counts, quick links, exam countdown
/// — is built in Phase 2 onward per the project plan; this just proves the
/// end-to-end signup -> profile -> home path works.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: profile.photoURL != null
                    ? NetworkImage(profile.photoURL!)
                    : null,
                child: profile.photoURL == null
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${profile.displayName}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                profile.exams.isEmpty
                    ? 'No exam selected yet'
                    : 'Preparing for: ${profile.exams.join(', ')}',
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
