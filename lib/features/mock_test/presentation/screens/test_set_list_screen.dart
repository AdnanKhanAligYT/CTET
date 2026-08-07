import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_attempt.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/test_set_repository.dart';
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
  bool _loading = true;
  String? _error;
  List<TestSet> _sets = const [];
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _open(TestSet set) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _opening) return;

    setState(() => _opening = true);
    try {
      final inProgress = await _repository.fetchInProgressAttempt(uid, set.id);
      TestAttempt? resumeAttempt;

      if (inProgress != null) {
        if (!mounted) return;
        final choice = await showDialog<_ResumeChoice>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pichla attempt mila'),
            content: Text(
              'Is test ka ek attempt pehle se chal raha hai '
              '(${_formatElapsed(inProgress.elapsedSeconds)} ho chuke hain). '
              'Wahin se jaari rakhein ya naya shuru karein?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_ResumeChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_ResumeChoice.fresh),
                child: const Text('Naya Start Karo'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_ResumeChoice.resume),
                child: const Text('Resume Karo'),
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
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 1) return '$seconds second';
    return '$minutes minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.paper.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.paper.name)),
        body: LoadError(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.paper.name)),
      body: SafeArea(
        child: _sets.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Is paper ke test abhi add nahi hue.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _sets.length,
                itemBuilder: (context, index) {
                  final set = _sets[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: _TestSetLogo(url: set.logoUrl),
                      title: Text(
                        set.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          set.subjects.join(', '),
                          if (set.timeLimitMinutes != null)
                            '${set.timeLimitMinutes} min',
                          if (set.year != null) '${set.year}',
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_opening,
                      onTap: () => _open(set),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

enum _ResumeChoice { resume, fresh, cancel }

/// The test set's admin-uploaded logo, or a plain quiz-icon tile (same
/// visual language as the dashboard's quick-link tiles) when there isn't
/// one — used both as the steady-state fallback and while a real logo is
/// still loading, so there's never a blank gap in the list.
class _TestSetLogo extends StatelessWidget {
  const _TestSetLogo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.tileMockTest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.quiz_outlined, color: Colors.white, size: 22),
    );

    final logoUrl = url;
    if (logoUrl == null || logoUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, _) => fallback,
        errorWidget: (context, _, _) => fallback,
      ),
    );
  }
}
