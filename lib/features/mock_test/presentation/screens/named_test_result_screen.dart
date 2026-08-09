import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/test_attempt.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/primary_button.dart';

/// Shown right after finishing a named Mock Test / PYQ set — same score
/// breakdown as the daily-practice TestResultScreen, plus this attempt's
/// rank against everyone else who has completed the same set. The rank is
/// a permanent snapshot (also stored on the `attempts` row itself), so
/// History shows the same numbers without recomputing them later.
class NamedTestResultScreen extends StatefulWidget {
  const NamedTestResultScreen({super.key, required this.attempt});

  final TestAttempt attempt;

  @override
  State<NamedTestResultScreen> createState() => _NamedTestResultScreenState();
}

class _NamedTestResultScreenState extends State<NamedTestResultScreen> {
  @override
  void initState() {
    super.initState();
    AdService.showAfterMockTest();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final attempted = attempt.correctCount + attempt.wrongCount;
    final skipped = attempt.totalQuestions - attempted;
    // Percentage is based on what was actually attempted, not the full
    // set length — a partial submission shouldn't be scored as if every
    // unanswered question were wrong.
    final percent = attempted == 0
        ? 0
        : (attempt.correctCount * 100 / attempted).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${attempt.correctCount} / $attempted correct (attempted)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (attempt.rank != null && attempt.participantsCount != null) ...[
                const SizedBox(height: 20),
                _RankBadge(
                  rank: attempt.rank!,
                  participants: attempt.participantsCount!,
                ),
              ],
              const SizedBox(height: 24),
              _StatRow(label: 'Attempted', value: attempted),
              _StatRow(label: 'Correct', value: attempt.correctCount),
              _StatRow(label: 'Wrong', value: attempt.wrongCount),
              if (skipped > 0) _StatRow(label: 'Skipped', value: skipped),
              const SizedBox(height: 32),
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
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.participants});

  final int rank;
  final int participants;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined),
          const SizedBox(width: 10),
          Text(
            'Aapki Rank: $rank / $participants',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
