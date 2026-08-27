import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/mock_test_session.dart';
import '../../../../core/models/test_attempt.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../../syllabus/presentation/syllabus_navigation.dart';
import '../../data/mock_test_local_store.dart';
import '../../data/student_shortcut_repository.dart';
import '../../data/test_set_repository.dart';
import 'mock_test_taking_screen.dart';
import 'named_test_screen.dart';

/// Third screen in the Mock Test / PYQ flow — named tests under one paper
/// (e.g. under "CTET Paper 1": "1st Hin Eng", "2nd ..."). Tapping one
/// either resumes an in-progress attempt or starts a brand new one —
/// unlike the daily due-today practice test, there's no "already done
/// today" restriction here, a set can be retaken as many times as wanted.
class TestSetListScreen extends StatefulWidget {
  const TestSetListScreen({super.key, required this.paper, required this.type});

  final ExamNode paper;
  final TestSetType type;

  @override
  State<TestSetListScreen> createState() => _TestSetListScreenState();
}

class _TestSetListScreenState extends State<TestSetListScreen> {
  final _repository = TestSetRepository();
  final _shortcutRepository = StudentShortcutRepository();
  bool _loading = true;
  String? _error;
  List<TestSet> _sets = const [];
  bool _opening = false;
  bool _isMyShortcut = false;
  bool _togglingShortcut = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadShortcutState();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sets = await _repository.fetchTestSets(widget.paper.id, widget.type);
      if (!mounted) return;
      setState(() {
        _sets = sets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // Separate from _load() (the test-set list itself) — a failure here just
  // means the star silently stays unfilled, no reason to block or error out
  // the whole screen over it.
  Future<void> _loadShortcutState() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final shortcut = await _shortcutRepository.fetchMyShortcut(uid);
      if (!mounted) return;
      final matches =
          shortcut != null &&
          shortcut.node.id == widget.paper.id &&
          shortcut.type == widget.type;
      setState(() => _isMyShortcut = matches);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleShortcut() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _togglingShortcut) return;
    setState(() => _togglingShortcut = true);
    try {
      if (_isMyShortcut) {
        await _shortcutRepository.unsetMyShortcut(uid);
      } else {
        await _shortcutRepository.setMyShortcut(
          uid,
          widget.paper.id,
          widget.type,
        );
      }
      if (!mounted) return;
      setState(() => _isMyShortcut = !_isMyShortcut);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _togglingShortcut = false);
    }
  }

  List<Widget> get _shortcutActions => [
    IconButton(
      icon: Icon(_isMyShortcut ? Icons.star : Icons.star_border),
      tooltip: _isMyShortcut
          ? 'Shortcut hai (hatane ke liye dabao)'
          : 'Mera Shortcut Bana Do',
      onPressed: _togglingShortcut ? null : _toggleShortcut,
    ),
  ];

  // Only the topmost test in the list is free — every other one shows a
  // full-screen interstitial ad first (see [isFree] in the itemBuilder).
  Future<void> _open(TestSet set, {required bool isFree}) async {
    if (_opening) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _opening = true);
    if (isFree) {
      await _proceedOpen(uid, set);
    } else {
      AdService.showBeforeOpeningContent(() => _proceedOpen(uid, set));
    }
  }

  Future<void> _proceedOpen(String uid, TestSet set) async {
    try {
      // Which flow to use is decided by the tab/catalog this screen was
      // opened under (widget.type), NOT the set's own primary `type` in the
      // DB — a set cross-listed into both (admin's "+ ... mein bhi dikhao")
      // must behave as Mock Test when opened from the Mock Test tab, and as
      // PYQ when opened from the PYQ tab, regardless of which one it was
      // originally created as.
      if (widget.type == TestSetType.mockTest) {
        await _openMockTest(uid, set);
      } else {
        await _openPyq(uid, set);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Mock Test: resume state lives entirely on-device (MockTestLocalStore)
  /// — no Supabase round-trip needed just to check whether a previous
  /// attempt exists. Fresh starts go through the instructions screen;
  /// resuming skips straight back into the test since instructions were
  /// already shown the first time.
  Future<void> _openMockTest(String uid, TestSet set) async {
    final localSession = await MockTestLocalStore().load(uid, set.id);
    MockTestSession? resumeSession;

    if (localSession != null) {
      if (!mounted) return;
      final choice = await showDialog<_ResumeChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Previous attempt found'),
          content: Text(
            'You already have an attempt in progress for this test '
            '(${_formatElapsed(localSession.elapsedSeconds)} so far). '
            'Continue from where you left off, or start over?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.fresh),
              child: const Text('Start New'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.resume),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (choice == null || choice == _ResumeChoice.cancel) return;
      if (choice == _ResumeChoice.resume) {
        resumeSession = localSession;
      } else {
        await MockTestLocalStore().clear(uid, set.id);
      }
    }

    if (!mounted) return;
    if (resumeSession != null) {
      context.push(
        '/mock-test/take-v2',
        extra: MockTestTakingArgs(testSet: set, resumeSession: resumeSession),
      );
    } else {
      context.push('/mock-test/instructions', extra: set);
    }
  }

  Future<void> _openPyq(String uid, TestSet set) async {
    final inProgress = await _repository.fetchInProgressAttempt(uid, set.id);
    TestAttempt? resumeAttempt;

    if (inProgress != null) {
      if (!mounted) return;
      final choice = await showDialog<_ResumeChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Previous attempt found'),
          content: Text(
            'You already have an attempt in progress for this test '
            '(${_formatElapsed(inProgress.elapsedSeconds)} so far). '
            'Continue from where you left off, or start over?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.fresh),
              child: const Text('Start New'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ResumeChoice.resume),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (choice == null || choice == _ResumeChoice.cancel) return;
      if (choice == _ResumeChoice.resume) {
        resumeAttempt = inProgress;
      } else {
        await _repository.abandonAttempt(inProgress.id);
      }
    }

    if (!mounted) return;
    context.push(
      '/mock-test/named',
      extra: NamedTestArgs(testSet: set, resumeAttempt: resumeAttempt),
    );
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 1) return '$seconds second';
    return '$minutes minute';
  }

  // Opens straight into the syllabus for this exact leaf (e.g.
  // "Science(Hin Eng)"), skipping the exam/paper picker entirely — this
  // screen already sits on the same admin-managed leaf that Syllabus keys
  // its content on, so there's nothing left to pick.
  void _openSyllabus() {
    AdService.showBeforeOpeningContent(() {
      if (!mounted) return;
      context.push(
        '/syllabus/topics',
        extra: SyllabusTopicsArgs(
          node: widget.paper,
          marksExam: resolveSyllabusMarksExam(widget.paper.name),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    late final Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = LoadError(message: _error!, onRetry: _load);
    } else if (_sets.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Is paper ke test abhi add nahi hue.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _sets.length,
        itemBuilder: (context, index) {
          final set = _sets[index];
          final isFree = index == 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: NetworkLogoAvatar(
                url: set.logoUrl,
                fallbackIcon: Icons.quiz_outlined,
                fallbackColor: AppColors.tileMockTest,
              ),
              // Shrunk to fit a long name (e.g. "7 Feb 26(Science
              // (Hin Urdu))") on one line on any device width,
              // instead of a fixed size that wraps to two lines.
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  set.name,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              subtitle: Text(
                [
                  set.subjects.join(', '),
                  if (set.timeLimitMinutes != null)
                    '${set.timeLimitMinutes} min',
                  if (set.year != null) '${set.year}',
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              trailing: isFree
                  ? const Icon(Icons.chevron_right)
                  : const Icon(Icons.lock_outline, size: 20),
              enabled: !_opening,
              onTap: () => _open(set, isFree: isFree),
            ),
          );
        },
      );
    }

    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(
        title: Text(widget.paper.name),
        actions: _shortcutActions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: _ShortcutHint(
                isMyShortcut: _isMyShortcut,
                onTap: _togglingShortcut ? null : _toggleShortcut,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: _SyllabusButton(onTap: _openSyllabus),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Tappable hint under the app bar spelling out what the star icon up
/// there does — the icon alone only explains itself on a long-press
/// tooltip, which most students never trigger.
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.isMyShortcut, required this.onTap});

  final bool isMyShortcut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isMyShortcut ? Icons.star : Icons.star_border,
              size: 18,
              color: AppColors.tileMockTest,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isMyShortcut
                    ? 'This is your shortcut — tap the star to remove it'
                    : 'Tap the star to set this as your shortcut',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyllabusButton extends StatelessWidget {
  const _SyllabusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.checklist_outlined),
        label: const Text('View your Syllabus'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tileSyllabus,
          side: BorderSide(color: AppColors.tileSyllabus),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

enum _ResumeChoice { resume, fresh, cancel }
