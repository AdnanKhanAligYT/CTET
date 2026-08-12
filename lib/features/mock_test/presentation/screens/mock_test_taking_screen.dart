import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/mock_test_session.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/mock_test_local_store.dart';
import '../../data/test_set_repository.dart';
import '../widgets/question_text.dart';
import 'mock_test_result_screen.dart';

class MockTestTakingArgs {
  const MockTestTakingArgs({required this.testSet, this.resumeSession});

  final TestSet testSet;

  /// Non-null only when the student chose "Resume Karo" on the
  /// local-in-progress-attempt prompt — see TestSetListScreen. Null means a
  /// fresh attempt (whether or not one existed locally before — a fresh
  /// start overwrites it).
  final MockTestSession? resumeSession;
}

enum _QuestionState { notVisited, notAnswered, answered, review }

class MockTestTakingScreen extends StatefulWidget {
  const MockTestTakingScreen({super.key, required this.args});

  final MockTestTakingArgs args;

  @override
  State<MockTestTakingScreen> createState() => _MockTestTakingScreenState();
}

class _MockTestTakingScreenState extends State<MockTestTakingScreen>
    with WidgetsBindingObserver {
  final _repository = TestSetRepository();
  final _localStore = MockTestLocalStore();
  Timer? _timer;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  List<Question> _questions = const [];
  Map<String, int> _answers = {};
  Set<String> _flagged = {};
  Set<String> _visited = {};
  int _elapsedSeconds = 0;
  late DateTime _startedAt;
  int _currentIndex = 0; // flat index into _questions (subject order)

  TestSet get _testSet => widget.args.testSet;
  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _saveLocal();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveLocal();
    }
  }

  Future<void> _load() async {
    final fetched = await _repository.fetchQuestions(_testSet.id);
    // Fixed subject order (matches the test set's declared order), then by
    // position within each subject — Next/Previous walk this flat order.
    final declaredSubjects = _testSet.subjects.toSet();
    final bySubject = <String, List<Question>>{
      for (final s in _testSet.subjects)
        s: fetched.where((q) => q.subject == s).toList(),
    };
    final questions = [
      for (final s in _testSet.subjects) ...(bySubject[s] ?? const []),
    ].where((q) => declaredSubjects.contains(q.subject)).toList();

    if (questions.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Is test mein abhi koi questions nahi hain.';
      });
      return;
    }

    final resume = widget.args.resumeSession;
    setState(() {
      _questions = questions;
      _startedAt = resume?.startedAt ?? DateTime.now();
      _elapsedSeconds = resume?.elapsedSeconds ?? 0;
      _answers = Map.of(resume?.answers ?? const {});
      _flagged = Set.of(resume?.flagged ?? const {});
      _visited = Set.of(resume?.visited ?? const {})
        ..add(questions.first.id);
      _loading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);

      final limitMinutes = _testSet.timeLimitMinutes;
      if (limitMinutes != null && _elapsedSeconds >= limitMinutes * 60) {
        _timer?.cancel();
        _submit(auto: true);
        return;
      }
      if (_elapsedSeconds % 10 == 0) _saveLocal();
    });
  }

  Future<void> _saveLocal() async {
    final uid = _uid;
    if (uid == null || _questions.isEmpty) return;
    await _localStore.save(
      uid,
      MockTestSession(
        testSetId: _testSet.id,
        startedAt: _startedAt,
        elapsedSeconds: _elapsedSeconds,
        answers: _answers,
        flagged: _flagged,
        visited: _visited,
      ),
    );
  }

  Question get _currentQuestion => _questions[_currentIndex];

  void _goTo(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() {
      _currentIndex = index;
      _visited = {..._visited, _questions[index].id};
    });
    _saveLocal();
  }

  void _selectOption(int optionIndex) {
    final q = _currentQuestion;
    setState(() {
      _answers = {..._answers, q.id: optionIndex};
    });
    _saveLocal();
  }

  void _toggleFlag() {
    final id = _currentQuestion.id;
    setState(() {
      final next = {..._flagged};
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      _flagged = next;
    });
    _saveLocal();
  }

  _QuestionState _stateOf(Question q) {
    if (_flagged.contains(q.id)) return _QuestionState.review;
    if (_answers.containsKey(q.id)) return _QuestionState.answered;
    if (_visited.contains(q.id)) return _QuestionState.notAnswered;
    return _QuestionState.notVisited;
  }

  Color _colorOf(_QuestionState state) {
    switch (state) {
      case _QuestionState.notVisited:
        return AppColors.navNotVisited;
      case _QuestionState.notAnswered:
        return AppColors.navNotAnswered;
      case _QuestionState.answered:
        return AppColors.navAnswered;
      case _QuestionState.review:
        return AppColors.navReview;
    }
  }

  Future<void> _openNavigator() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _NavigatorSheet(
        testSet: _testSet,
        questions: _questions,
        stateOf: _stateOf,
        colorOf: _colorOf,
        currentIndex: _currentIndex,
        onJump: (index) {
          Navigator.of(sheetContext).pop();
          _goTo(index);
        },
        onSubmit: () {
          Navigator.of(sheetContext).pop();
          _confirmAndSubmit();
        },
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    final counts = _subjectCounts();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test submit karna hai?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final subject in _testSet.subjects)
                if (counts.containsKey(subject)) ...[
                  Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Answered: ${counts[subject]!.answered}  ·  '
                    'Not Answered: ${counts[subject]!.notAnswered}  ·  '
                    'Review: ${counts[subject]!.review}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                ],
              const Text('Are you sure?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed == true) _submit();
  }

  Map<String, _SubjectCounts> _subjectCounts() {
    final map = <String, _SubjectCounts>{};
    for (final q in _questions) {
      final c = map.putIfAbsent(q.subject, () => _SubjectCounts());
      final state = _stateOf(q);
      if (state == _QuestionState.review) {
        c.review++;
      } else if (state == _QuestionState.answered) {
        c.answered++;
      } else {
        c.notAnswered++;
      }
    }
    return map;
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    final uid = _uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    var correct = 0;
    var wrong = 0;
    for (final q in _questions) {
      final selected = _answers[q.id];
      if (selected == null) continue;
      if (selected == q.correctOptionIndex) {
        correct++;
      } else {
        wrong++;
      }
    }

    try {
      final attempt = await _repository.submitMockTestAttempt(
        uid: uid,
        setId: _testSet.id,
        totalQuestions: _questions.length,
        correctCount: correct,
        wrongCount: wrong,
        elapsedSeconds: _elapsedSeconds,
        startedAt: _startedAt,
      );
      await _localStore.clear(uid, _testSet.id);
      if (!mounted) return;
      if (auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time up! Test automatically submit ho gaya.')),
        );
      }
      context.pushReplacement(
        '/mock-test/result-v2',
        extra: MockTestResultArgs(
          attempt: attempt,
          questions: _questions,
          answers: _answers,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit nahi ho paya: $e')));
    }
  }

  /// Back button/gesture during a test doesn't just exit silently —
  /// progress is already autosaved locally either way, so this is purely a
  /// "did you mean to leave?" guard against accidental exits mid-exam.
  Future<bool> _confirmExit() async {
    await _saveLocal();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test chhodke jana hai?'),
        content: const Text(
          'Aapki progress save ho gayi hai — baad mein isi test ko khol ke '
          'wahin se jaari rakh sakte hain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Test Mein Rahein'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Chhod Dein'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  String _formatElapsed() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_testSet.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final q = _currentQuestion;
    final selected = _answers[q.id];
    final flagged = _flagged.contains(q.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_testSet.name),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatElapsed(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Navigator',
              onPressed: _openNavigator,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  'Question ${_currentIndex + 1} of '
                  '${_questions.length} — ${q.subject}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    QuestionText(
                      question: q,
                      number: _currentIndex + 1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < q.options.length; i++)
                      _SelectableOptionTile(
                        letter: _optionLetter(i),
                        text: q.options[i],
                        selected: selected == i,
                        isUrdu: q.isUrdu,
                        onTap: () => _selectOption(i),
                      ),
                  ],
                ),
              ),
              _BottomBar(
                flagged: flagged,
                canGoPrevious: _currentIndex > 0,
                canGoNext: _currentIndex < _questions.length - 1,
                onFlag: _toggleFlag,
                onPrevious: () => _goTo(_currentIndex - 1),
                onNext: () => _goTo(_currentIndex + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCounts {
  int answered = 0;
  int notAnswered = 0;
  int review = 0;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.flagged,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onFlag,
    required this.onPrevious,
    required this.onNext,
  });

  final bool flagged;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onFlag;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: onFlag,
              icon: Icon(
                flagged ? Icons.flag : Icons.outlined_flag,
                color: flagged ? AppColors.navReview : null,
              ),
              label: Text(flagged ? 'Flagged' : 'Flag'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: canGoPrevious ? onPrevious : null,
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: canGoNext ? onNext : null,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
    this.isUrdu = false,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool isUrdu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? (isDark ? AppColors.navyLight : AppColors.navy)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final badgeColor = selected
        ? (isDark ? AppColors.navyLight : AppColors.navy)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? (isDark ? AppColors.navy : AppColors.navy)
                      .withValues(alpha: isDark ? 0.28 : 0.06)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: badgeColor,
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  textAlign: isUrdu ? TextAlign.right : null,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: isDark ? AppColors.navyLight : AppColors.navy,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!isUrdu) return card;
    return Directionality(textDirection: TextDirection.rtl, child: card);
  }
}

class _NavigatorSheet extends StatelessWidget {
  const _NavigatorSheet({
    required this.testSet,
    required this.questions,
    required this.stateOf,
    required this.colorOf,
    required this.currentIndex,
    required this.onJump,
    required this.onSubmit,
  });

  final TestSet testSet;
  final List<Question> questions;
  final _QuestionState Function(Question) stateOf;
  final Color Function(_QuestionState) colorOf;
  final int currentIndex;
  final ValueChanged<int> onJump;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Question Navigator',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _LegendDot(color: AppColors.navNotVisited, label: 'Not Visited'),
                  _LegendDot(color: AppColors.navNotAnswered, label: 'Not Answered'),
                  _LegendDot(color: AppColors.navAnswered, label: 'Answered'),
                  _LegendDot(color: AppColors.navReview, label: 'Review'),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    for (final subject in testSet.subjects)
                      _SubjectBubbleGroup(
                        subject: subject,
                        questions: questions,
                        stateOf: stateOf,
                        colorOf: colorOf,
                        currentIndex: currentIndex,
                        onJump: onJump,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onSubmit,
                child: const Text('Submit Test'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SubjectBubbleGroup extends StatelessWidget {
  const _SubjectBubbleGroup({
    required this.subject,
    required this.questions,
    required this.stateOf,
    required this.colorOf,
    required this.currentIndex,
    required this.onJump,
  });

  final String subject;
  final List<Question> questions;
  final _QuestionState Function(Question) stateOf;
  final Color Function(_QuestionState) colorOf;
  final int currentIndex;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final entries = <(int, Question)>[
      for (var i = 0; i < questions.length; i++)
        if (questions[i].subject == subject) (i, questions[i]),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      title: Text(
        subject,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      initiallyExpanded: entries.any((e) => e.$1 == currentIndex),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, question) in entries)
                _QuestionBubble(
                  number: index + 1,
                  color: colorOf(stateOf(question)),
                  isCurrent: index == currentIndex,
                  onTap: () => onJump(index),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.number,
    required this.color,
    required this.isCurrent,
    required this.onTap,
  });

  final int number;
  final Color color;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isCurrent
              ? Border.all(color: Colors.black87, width: 2)
              : null,
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

String _optionLetter(int i) => String.fromCharCode(65 + i);
