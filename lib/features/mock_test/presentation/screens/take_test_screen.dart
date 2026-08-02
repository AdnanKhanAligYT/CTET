import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/question.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/application/profile_controller.dart';
import '../../data/mock_test_repository.dart';
import '../../domain/question_progress.dart';
import '../../domain/spaced_repetition_service.dart';
import 'test_result_screen.dart';

/// Mirrors `take_test.php` from the reference app: always just today's due
/// questions (new + anything whose revision date has arrived) in mixed
/// order, instant feedback + explanation the moment an option is picked,
/// answers locked once chosen, and a choice after each question to
/// continue or stop and see the result — answered questions already have
/// their next due date set, so stopping early never repeats what's done.
class TakeTestScreen extends ConsumerStatefulWidget {
  const TakeTestScreen({super.key});

  @override
  ConsumerState<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends ConsumerState<TakeTestScreen> {
  final _repository = MockTestRepository();
  final _spacedRepetition = const SpacedRepetitionService();

  bool _loading = true;
  String? _errorMessage;
  List<Question> _dueQuestions = const [];
  Map<String, QuestionProgress> _progress = const {};

  int _currentIndex = 0;
  int? _selectedOption;
  bool _locked = false;
  int _correctCount = 0;
  int _wrongCount = 0;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(userProfileProvider.future);
    final exams = profile?.exams ?? const [];
    if (exams.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage =
            'No exam selected yet — pick one in Edit Profile first.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final allQuestions = await _repository.fetchQuestionsForExams(exams);
    final progress = await _repository.fetchProgress(user.uid);

    final due =
        allQuestions
            .where((q) => _spacedRepetition.isDueToday(progress[q.id]))
            .toList()
          ..shuffle();

    if (!mounted) return;
    setState(() {
      _dueQuestions = due;
      _progress = progress;
      _loading = false;
    });
  }

  Question get _currentQuestion => _dueQuestions[_currentIndex];

  Future<void> _selectOption(int index) async {
    if (_locked) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final question = _currentQuestion;
    final wasCorrect = index == question.correctOptionIndex;

    setState(() {
      _selectedOption = index;
      _locked = true;
      if (wasCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
    });

    final updatedProgress = _spacedRepetition.recordAnswer(
      questionId: question.id,
      current: _progress[question.id],
      wasCorrect: wasCorrect,
    );
    _progress = {..._progress, question.id: updatedProgress};
    await _repository.saveProgress(user.uid, updatedProgress);
  }

  void _next() {
    if (_currentIndex + 1 < _dueQuestions.length) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _locked = false;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _repository.saveAttempt(
        uid: user.uid,
        totalQuestions: _dueQuestions.length,
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        startedAt: _startedAt,
        submittedAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestResultScreen(
          correctCount: _correctCount,
          wrongCount: _wrongCount,
          totalQuestions: _dueQuestions.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Test')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Go to Profile',
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_dueQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Test')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No questions due today — you\'re all caught up! Check back tomorrow.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final question = _currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_dueQuestions.length}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(question.subject)),
                if (question.topic.isNotEmpty)
                  Chip(label: Text(question.topic)),
              ],
            ),
            const SizedBox(height: 16),
            Text(question.text, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            for (var i = 0; i < question.options.length; i++)
              _OptionTile(
                text: question.options[i],
                state: _optionState(question, i),
                onTap: () => _selectOption(i),
              ),
            if (_locked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface)
                          .withValues(alpha: 0.6),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.explanationFor(_selectedOption!),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _finish,
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
          ],
        ),
      ),
    );
  }

  _OptionVisualState _optionState(Question question, int index) {
    if (!_locked) return _OptionVisualState.neutral;
    if (index == question.correctOptionIndex) return _OptionVisualState.correct;
    if (index == _selectedOption) return _OptionVisualState.wrong;
    return _OptionVisualState.disabled;
  }
}

enum _OptionVisualState { neutral, correct, wrong, disabled }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _OptionVisualState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    Color? fillColor;
    IconData? icon;

    switch (state) {
      case _OptionVisualState.neutral:
        break;
      case _OptionVisualState.correct:
        borderColor = Colors.green;
        fillColor = Colors.green.withValues(alpha: 0.12);
        icon = Icons.check_circle;
        break;
      case _OptionVisualState.wrong:
        borderColor = AppColors.error;
        fillColor = AppColors.error.withValues(alpha: 0.12);
        icon = Icons.cancel;
        break;
      case _OptionVisualState.disabled:
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
            children: [
              Expanded(child: Text(text)),
              if (icon != null) Icon(icon, color: borderColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
