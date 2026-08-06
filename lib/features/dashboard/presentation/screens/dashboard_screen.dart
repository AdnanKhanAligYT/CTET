import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';

/// Home screen: profile summary up top, the study-tool quick-link tiles
/// (Mock Test, Previous Year Questions, Syllabus, ...) — see
/// `core/services/ad_service.dart` for how the banner ad unit is wired
/// (test IDs until a real AdMob account is linked).
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: profile.photoURL != null
                            ? NetworkImage(profile.photoURL!)
                            : null,
                        child: profile.photoURL == null
                            ? const Icon(Icons.person, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${profile.displayName}!',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              profile.exams.isEmpty
                                  ? 'No exam selected yet'
                                  : 'Preparing for: ${profile.exams.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _QuickLinkTile(
                    icon: Icons.quiz_outlined,
                    color: AppColors.tileMockTest,
                    title: 'Mock Test',
                    subtitle: 'Exam chuno, phir test',
                    onTap: () => context.push('/mock-test'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.history_edu_outlined,
                    color: AppColors.tilePyq,
                    title: 'Previous Year Questions',
                    subtitle: 'Exam chuno, phir purane papers',
                    onTap: () => context.push('/pyq'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.checklist_outlined,
                    color: AppColors.tileSyllabus,
                    title: 'Syllabus Tracker',
                    subtitle: 'Mark topics as you cover them',
                    onTap: () => context.push('/syllabus'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.menu_book_outlined,
                    color: AppColors.tileDictionary,
                    title: 'Dictionary',
                    subtitle: 'Daily vocabulary revision',
                    onTap: () => context.push('/dictionary'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.tileTimetable,
                    title: 'Timetable',
                    subtitle: 'Your weekly study schedule',
                    onTap: () => context.push('/timetable'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.edit_note_outlined,
                    color: AppColors.tileNotepad,
                    title: 'Notepad',
                    subtitle: 'Quick notes while you study',
                    onTap: () => context.push('/notepad'),
                  ),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.history,
                    color: AppColors.tileHistory,
                    title: 'History',
                    subtitle: 'Your past mock test scores',
                    onTap: () => context.push('/history'),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            ),
            const AppBannerAd(),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
