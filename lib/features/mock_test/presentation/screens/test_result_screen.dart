import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/primary_button.dart';

class TestResultScreen extends StatefulWidget {
  const TestResultScreen({
    super.key,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
  });

  final int correctCount;
  final int wrongCount;
  final int totalQuestions;

  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends State<TestResultScreen> {
  @override
  void initState() {
    super.initState();
    // Shown right after a natural stopping point (test finished), not
    // mid-question — the least disruptive moment for an interstitial.
    AdService.showAfterMockTest();
  }

  @override
  Widget build(BuildContext context) {
    final skipped =
        widget.totalQuestions - widget.correctCount - widget.wrongCount;
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
                '${widget.correctCount} / ${widget.totalQuestions}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Correct answers',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _StatRow(label: 'Correct', value: widget.correctCount),
              _StatRow(label: 'Wrong', value: widget.wrongCount),
              if (skipped > 0) _StatRow(label: 'Skipped', value: skipped),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
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
