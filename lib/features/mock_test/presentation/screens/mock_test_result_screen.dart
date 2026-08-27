import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/question.dart';
import '../../../../core/models/test_attempt.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../widgets/question_text.dart';

/// [questions]/[answers] are the LOCAL in-memory state MockTestTakingScreen
/// just submitted with — never re-fetched from Supabase, since no
/// per-question answer data is stored there (see MockTestSession's doc
/// comment). This means the detailed per-question review below only exists
/// for this one viewing, right after submit; History shows the aggregate
/// [attempt] fields (score/rank/percentile) only.
class MockTestResultArgs {
  const MockTestResultArgs({
    required this.attempt,
    required this.questions,
    required this.answers,
  });

  final TestAttempt attempt;
  final List<Question> questions;
  final Map<String, int> answers;
}

class MockTestResultScreen extends StatefulWidget {
  const MockTestResultScreen({super.key, required this.args});

  final MockTestResultArgs args;

  @override
  State<MockTestResultScreen> createState() => _MockTestResultScreenState();
}

class _MockTestResultScreenState extends State<MockTestResultScreen> {
  @override
  void initState() {
    super.initState();
    AdService.showAfterMockTest();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.args.attempt;
    final questions = widget.args.questions;
    final answers = widget.args.answers;
    final attempted = attempt.correctCount + attempt.wrongCount;
    final accuracy = attempted == 0
        ? 0
        : (attempt.correctCount * 100 / attempted).round();

    return Scaffold(
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Rank',
                    value: attempt.rank != null && attempt.participantsCount != null
                        ? '${attempt.rank} / ${attempt.participantsCount}'
                        : '—',
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Marks',
                    value: '${attempt.correctCount} / ${attempt.totalQuestions}',
                    icon: Icons.grade_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Attempted',
                    value: '$attempted / ${attempt.totalQuestions}',
                    icon: Icons.fact_check_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Accuracy',
                    value: '$accuracy%',
                    icon: Icons.track_changes_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatCard(
              label: 'Percentile',
              value: attempt.percentile != null
                  ? '${attempt.percentile!.toStringAsFixed(2)}%ile'
                  : '—',
              icon: Icons.bar_chart_outlined,
              fullWidth: true,
            ),
            const SizedBox(height: 28),
            Text(
              'Sawaal-Dar-Sawaal Review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < questions.length; i++)
              _QuestionReviewCard(
                number: i + 1,
                question: questions[i],
                selected: answers[questions[i].id],
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'History Dekho',
              onPressed: () => context.go('/history'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.navyLight : AppColors.navy),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ReviewStatus { correct, incorrect, notAttempted }

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({
    required this.number,
    required this.question,
    required this.selected,
  });

  final int number;
  final Question question;
  final int? selected;

  _ReviewStatus get _status {
    if (selected == null) return _ReviewStatus.notAttempted;
    return selected == question.correctOptionIndex
        ? _ReviewStatus.correct
        : _ReviewStatus.incorrect;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Color color;
    late final String label;
    switch (_status) {
      case _ReviewStatus.correct:
        color = Colors.green;
        label = 'Correct';
        break;
      case _ReviewStatus.incorrect:
        color = AppColors.error;
        label = 'Incorrect';
        break;
      case _ReviewStatus.notAttempted:
        color = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
        label = 'Not Attempted';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: QuestionText(
                  question: question,
                  number: number,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
              'Aapka jawab: ${question.options[selected!]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Sahi jawab: ${question.options[question.correctOptionIndex]}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
