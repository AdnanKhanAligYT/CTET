import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/history_repository.dart';
import '../../domain/attempt.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = HistoryRepository();
  bool _loading = true;
  List<Attempt> _attempts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final attempts = await _repository.fetchAttempts(uid);
    if (!mounted) return;
    setState(() {
      _attempts = attempts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: _attempts.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No mock tests attempted yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _attempts.length,
                itemBuilder: (context, index) =>
                    _AttemptCard(attempt: _attempts[index]),
              ),
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final skipped =
        attempt.totalQuestions - attempt.correctCount - attempt.wrongCount;
    final accuracy = attempt.totalQuestions == 0
        ? 0
        : (attempt.correctCount / attempt.totalQuestions * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('d MMM y, h:mm a').format(attempt.submittedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '$accuracy%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${attempt.correctCount} correct · ${attempt.wrongCount} wrong'
              '${skipped > 0 ? ' · $skipped skipped' : ''} '
              '(${attempt.totalQuestions} total)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
