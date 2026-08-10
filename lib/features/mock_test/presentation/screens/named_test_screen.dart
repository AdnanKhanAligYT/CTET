import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/models/question.dart';
import '../../../../core/models/test_attempt.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_submit_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/test_set_repository.dart';

/// Bundles what NamedTestScreen needs from the previous screen — the set
/// being started, and (if the student chose "Resume Karo" on an existing
/// in_progress attempt) the attempt to resume from.
class NamedTestArgs {
  const NamedTestArgs({required this.testSet, this.resumeAttempt});

  final TestSet testSet;
  final TestAttempt? resumeAttempt;
}

class NamedTestScreen extends StatefulWidget {
  const NamedTestScreen({super.key, required this.args});

  final NamedTestArgs args;

  @override
  State<NamedTestScreen> createState() => _NamedTestScreenState();
}

class _NamedTestScreenState extends State<NamedTestScreen>
    with WidgetsBindingObserver {
  final _repository = TestSetRepository();
  Timer? _timer;

  bool _loading = true;
  String? _errorMessage;
  String? _attemptId;
  List<Question> _questions = const [];
  Map<String, List<Question>> _subjectQuestions = const {};

  Map<String, int> _answers = {};
  int _currentSubjectIndex = 0;
  int _elapsedSeconds = 0;
  int _correctCount = 0;
  int _wrongCount = 0;

  // The question whose instant-feedback panel is currently showing —
  // null means "show the next unanswered question's options instead".
  Question? _feedbackQuestion;
  int? _feedbackSelection;

  TestSet get _testSet => widget.args.testSet;

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
    _saveProgress();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveProgress();
    }
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final fetchedQuestions = await _repository.fetchQuestions(_testSet.id);
    // Only questions whose subject is one of this set's declared subjects
    // are reachable through any tab (see _subjectQuestions below). A
    // tagged question left over after the subjects list was edited (or
    // ever mistagged) would otherwise still count toward "every question
    // answered" while never being shown anywhere to actually answer —
    // permanently blocking _allSubjectsComplete from ever becoming true.
    final declaredSubjects = _testSet.subjects.toSet();
    final questions = fetchedQuestions
        .where((q) => declaredSubjects.contains(q.subject))
        .toList();
    final bySubject = <String, List<Question>>{
      for (final subject in _testSet.subjects)
        subject: questions.where((q) => q.subject == subject).toList(),
    };

    if (questions.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Is test mein abhi koi questions nahi hain.';
      });
      return;
    }

    final resume = widget.args.resumeAttempt;
    final attempt =
        resume ??
        await _repository.startAttempt(
          uid: uid,
          setId: _testSet.id,
          totalQuestions: questions.length,
        );

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _subjectQuestions = bySubject;
      _attemptId = attempt.id;
      _answers = Map.of(attempt.answers);
      _currentSubjectIndex = attempt.currentSubjectIndex;
      _elapsedSeconds = attempt.elapsedSeconds;
      _correctCount = attempt.correctCount;
      _wrongCount = attempt.wrongCount;
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
        _finish();
        return;
      }
      if (_elapsedSeconds % 15 == 0) _saveProgress();
    });
  }

  Future<void> _saveProgress() {
    final attemptId = _attemptId;
    if (attemptId == null) return Future.value();
    return _repository.saveProgress(
      attemptId: attemptId,
      currentSubjectIndex: _currentSubjectIndex,
      answers: _answers,
      elapsedSeconds: _elapsedSeconds,
      correctCount: _correctCount,
      wrongCount: _wrongCount,
    );
  }

  List<Question> get _currentSubjectQuestions {
    if (_testSet.subjects.isEmpty) return const [];
    final subject = _testSet.subjects[_currentSubjectIndex];
    return _subjectQuestions[subject] ?? const [];
  }

  Question? get _currentQuestion {
    for (final q in _currentSubjectQuestions) {
      if (!_answers.containsKey(q.id)) return q;
    }
    return null;
  }

  bool get _allSubjectsComplete =>
      _questions.every((q) => _answers.containsKey(q.id));

  Future<void> _selectOption(Question question, int index) async {
    if (_feedbackQuestion != null) return;
    final wasCorrect = index == question.correctOptionIndex;
    setState(() {
      _answers = {..._answers, question.id: index};
      _feedbackQuestion = question;
      _feedbackSelection = index;
      if (wasCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
    });
    await _saveProgress();
  }

  void _goToNextIncompleteSubject() {
    for (var i = 0; i < _testSet.subjects.length; i++) {
      final qs = _subjectQuestions[_testSet.subjects[i]] ?? const [];
      if (qs.any((q) => !_answers.containsKey(q.id))) {
        setState(() => _currentSubjectIndex = i);
        _saveProgress();
        return;
      }
    }
  }

  void _next() {
    setState(() {
      _feedbackQuestion = null;
      _feedbackSelection = null;
    });
    if (_currentQuestion == null && !_allSubjectsComplete) {
      _goToNextIncompleteSubject();
    }
  }

  void _jumpToSubject(int index) {
    setState(() {
      _currentSubjectIndex = index;
      _feedbackQuestion = null;
      _feedbackSelection = null;
    });
    _saveProgress();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final result = await _repository.finishAttempt(
      attemptId: attemptId,
      setId: _testSet.id,
      elapsedSeconds: _elapsedSeconds,
      correctCount: _correctCount,
      wrongCount: _wrongCount,
    );
    if (!mounted) return;
    context.pushReplacement('/mock-test/named/result', extra: result);
  }

  Future<void> _confirmAndFinish() async {
    final attempted = _correctCount + _wrongCount;
    final confirmed = await confirmSubmitTest(
      context: context,
      attempted: attempted,
      total: _questions.length,
    );
    if (confirmed) _finish();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_testSet.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _formatElapsed(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SubjectTabs(
              subjects: _testSet.subjects,
              currentIndex: _currentSubjectIndex,
              onSelected: _jumpToSubject,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_feedbackQuestion != null) {
      return _buildFeedback(_feedbackQuestion!, _feedbackSelection!);
    }
    final question = _currentQuestion;
    if (question != null) {
      return _buildQuestion(question);
    }
    if (_allSubjectsComplete) {
      return _buildAllComplete();
    }
    // A subject's questions just ran out but others remain — should be
    // momentary, _next()/_jumpToSubject already route around this, but
    // show a way forward if this state is ever reached directly.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yeh subject poora ho gaya.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Agla Subject',
              onPressed: _goToNextIncompleteSubject,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(Question question) {
    final number = _currentSubjectQuestions.indexOf(question) + 1;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Question $number of '
          '${_currentSubjectQuestions.length} — ${question.subject}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Q$number. ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: question.text),
            ],
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++)
          _OptionTile(
            letter: _optionLetter(i),
            text: question.options[i],
            state: _OptionVisualState.neutral,
            onTap: () => _selectOption(question, i),
          ),
      ],
    );
  }

  Widget _buildFeedback(Question question, int selected) {
    final number = _currentSubjectQuestions.indexOf(question) + 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Q$number. ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: question.text),
            ],
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++)
          _OptionTile(
            letter: _optionLetter(i),
            text: question.options[i],
            state: i == question.correctOptionIndex
                ? _OptionVisualState.correct
                : (i == selected
                      ? _OptionVisualState.wrong
                      : _OptionVisualState.disabled),
            onTap: () {},
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isDark ? Colors.indigo.shade900 : Colors.indigo.shade50)
                .withValues(alpha: isDark ? 0.35 : 1),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: isDark
                        ? Colors.indigo.shade200
                        : Colors.indigo.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Explanation',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? Colors.indigo.shade200
                          : Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                question.explanationFor(selected),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmAndFinish,
                child: const Text('Submit & Finish'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(label: 'Next →', onPressed: _next),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saare subjects poore ho gaye! 🎉',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_correctCount correct · $_wrongCount wrong '
              '(${_questions.length} total)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Result Dekho', onPressed: _finish),
          ],
        ),
      ),
    );
  }
}

class _SubjectTabs extends StatelessWidget {
  const _SubjectTabs({
    required this.subjects,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<String> subjects;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < subjects.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(subjects[i]),
                selected: currentIndex == i,
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

enum _OptionVisualState { neutral, correct, wrong, disabled }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionVisualState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    Color? fillColor;
    Color badgeColor = isDark ? AppColors.navyLight : AppColors.navy;
    IconData? icon;

    switch (state) {
      case _OptionVisualState.neutral:
        break;
      case _OptionVisualState.correct:
        borderColor = Colors.green;
        fillColor = Colors.green.withValues(alpha: 0.12);
        badgeColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case _OptionVisualState.wrong:
        borderColor = AppColors.error;
        fillColor = AppColors.error.withValues(alpha: 0.12);
        badgeColor = AppColors.error;
        icon = Icons.cancel;
        break;
      case _OptionVisualState.disabled:
        badgeColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: state == _OptionVisualState.neutral ? 1 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: fillColor,
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
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: borderColor, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A/B/C/D/... for option index [i] (0 = A, 1 = B, ...).
String _optionLetter(int i) => String.fromCharCode(65 + i);
