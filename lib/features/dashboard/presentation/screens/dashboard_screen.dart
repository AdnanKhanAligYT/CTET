import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/user_profile.dart';
import '../../../../core/routing/route_observer.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/app_settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../mock_test/data/exam_catalog_repository.dart';
import '../../../mock_test/data/student_shortcut_repository.dart';
import '../../../mock_test/presentation/exam_navigation.dart';
import '../widgets/exam_countdown_bar.dart';

/// Home screen: profile summary up top, the study-tool quick-link tiles
/// (Mock Test, Previous Year Questions, Syllabus, ...) — see
/// `core/services/ad_service.dart` for how the banner ad unit is wired
/// (test IDs until a real AdMob account is linked).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with RouteAware {
  final _examRepository = ExamCatalogRepository();
  final _shortcutRepository = StudentShortcutRepository();
  StudentShortcut? _shortcut;
  bool _opening = false;
  DateTime? _examCountdownDate;

  @override
  void initState() {
    super.initState();
    _loadShortcut();
    _loadExamCountdownDate();
  }

  // Same admin-set date/time NotificationService's 7:30 AM reminder
  // already reads — only shown once it's confirmed still in the future,
  // so a stale past date never flashes on screen before hiding itself.
  Future<void> _loadExamCountdownDate() async {
    try {
      final date = await AppSettingsRepository().fetchExamCountdownDate();
      if (!mounted) return;
      setState(() {
        _examCountdownDate = (date != null && date.isAfter(DateTime.now()))
            ? date
            : null;
      });
    } catch (_) {
      // No countdown bar is an acceptable fallback — same stance as the
      // shortcut tile above.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Fires when a screen pushed on top of this one (e.g. the star toggle
  // on TestSetListScreen) gets popped and Dashboard becomes visible
  // again — without this, a just-set/just-cleared shortcut only showed
  // up after a full app restart, since initState() never re-runs for a
  // widget that's still alive further down the stack.
  @override
  void didPopNext() {
    _loadShortcut();
  }

  // Failure here isn't worth an error banner over — the shortcut is a
  // convenience on top of the always-available Mock Test tile below it, so
  // silently showing no shortcut (same as "none set") is an acceptable
  // fallback.
  Future<void> _loadShortcut() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final shortcut = await _shortcutRepository.fetchMyShortcut(uid);
      if (!mounted) return;
      setState(() => _shortcut = shortcut);
    } catch (_) {
      // ignore — dashboard still works fine without the shortcut tile.
    }
  }

  Future<void> _openShortcut() async {
    final shortcut = _shortcut;
    if (shortcut == null || _opening) return;
    setState(() => _opening = true);
    try {
      await navigateIntoExamNode(
        context: context,
        repository: _examRepository,
        node: shortcut.node,
        type: shortcut.type,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
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
        bottom: _examCountdownDate != null
            ? ExamCountdownBar(examDate: _examCountdownDate!)
            : null,
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
                  if (_shortcut != null) ...[
                    _QuickLinkTile(
                      icon: Icons.bolt,
                      color: AppColors.tileMockTest,
                      title: _shortcut!.node.name,
                      subtitle: 'Shortcut — seedha yahan pahunch jao',
                      onTap: _openShortcut,
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  const Center(child: AppBannerAd()),
                  const SizedBox(height: 12),
                  _QuickLinkTile(
                    icon: Icons.auto_stories_outlined,
                    color: AppColors.tileMockTest,
                    title: 'Subject Wise Revision',
                    subtitle: 'Subject chuno, turant test shuru',
                    onTap: () => context.push('/mock-test/subjects'),
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
