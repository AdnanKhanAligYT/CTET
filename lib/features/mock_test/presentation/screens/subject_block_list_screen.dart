import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_test_repository.dart';
import '../../data/question_dedupe.dart';
import '../subject_style.dart';

/// Behind a Subject Wise Revision subject tap — splits that subject's
/// question pool into fixed chunk-of-N blocks (30 per block, 60 for SST
/// — the same chunkSizeForSubject used for the exam-wise Mock Test/PYQ
/// checkpoints) so a student picks "CDP 1st", "CDP 2nd", etc. rather than
/// always starting the whole subject in one sitting. Block membership is
/// stable (sorted by question id in TakeTestScreen) — "CDP 1st" always
/// means the same ~30 questions; only the order *within* a block once
/// the test starts follows the card-stack recency sort.
class SubjectBlockListScreen extends StatefulWidget {
  const SubjectBlockListScreen({super.key, required this.subject});

  final String subject;

  @override
  State<SubjectBlockListScreen> createState() =>
      _SubjectBlockListScreenState();
}

class _SubjectBlockListScreenState extends State<SubjectBlockListScreen> {
  final _repository = MockTestRepository();
  bool _loading = true;
  String? _errorMessage;
  int _totalQuestions = 0;
  int _chunkSize = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final subjectQuestions = await _repository.fetchQuestionsForSubject(
        widget.subject,
      );
      final pool = dedupeByText(subjectQuestions);
      if (!mounted) return;
      setState(() {
        _totalQuestions = pool.length;
        _chunkSize = chunkSizeForSubject(widget.subject);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(widget.subject);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final blockCount = (_totalQuestions / _chunkSize).ceil();

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: SafeArea(
        child: blockCount == 0
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Abhi is subject ke questions upload nahi hue.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: blockCount,
                itemBuilder: (context, index) {
                  final start = index * _chunkSize;
                  final end = (start + _chunkSize).clamp(0, _totalQuestions);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color,
                        child: Icon(style.icon, color: Colors.white),
                      ),
                      title: Text(
                        '${widget.subject} ${_ordinal(index + 1)}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: style.color,
                            ),
                      ),
                      subtitle: Text('${end - start} questions'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/mock-test/take?subject=${Uri.encodeComponent(widget.subject)}&block=$index',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11-13 -> "th" (English
/// ordinal suffix rules, including the 11th/12th/13th exception).
String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
