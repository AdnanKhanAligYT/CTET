import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/question.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/mock_test_repository.dart';
import '../../data/question_dedupe.dart';
import '../subject_style.dart';

/// Behind the dashboard's "Subject Wise Revision" tile — the subject list
/// isn't admin-managed, it's derived on the fly from whatever questions
/// already exist, so it always matches the data that's actually been
/// uploaded (see MockTestRepository.fetchAllQuestions for why this isn't
/// scoped to the student's own exam selection). Tapping a subject jumps
/// straight into TakeTestScreen for that subject.
class SubjectRevisionListScreen extends StatefulWidget {
  const SubjectRevisionListScreen({super.key});

  @override
  State<SubjectRevisionListScreen> createState() =>
      _SubjectRevisionListScreenState();
}

class _SubjectRevisionListScreenState
    extends State<SubjectRevisionListScreen> {
  final _repository = MockTestRepository();
  bool _loading = true;
  String? _errorMessage;
  List<MapEntry<String, int>> _subjectCounts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final questions = await _repository.fetchAllQuestions();
      final bySubject = <String, List<Question>>{};
      for (final question in questions) {
        if (question.subject.isEmpty) continue;
        bySubject.putIfAbsent(question.subject, () => []).add(question);
      }
      // Deduped per subject (same rule TakeTestScreen applies when it
      // actually builds the run) so the count shown here always matches
      // how many unique questions the student will actually see.
      final entries =
          bySubject.entries
              .map((e) => MapEntry(e.key, dedupeByText(e.value).length))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));

      if (!mounted) return;
      setState(() {
        _subjectCounts = entries;
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subject Wise Revision')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Wise Revision')),
      body: SafeArea(
        child: _subjectCounts.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Abhi tak koi question upload nahi hua hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _subjectCounts.length,
                itemBuilder: (context, index) {
                  final entry = _subjectCounts[index];
                  final style = subjectStyleFor(entry.key);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color,
                        child: Icon(style.icon, color: Colors.white),
                      ),
                      title: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: style.color,
                            ),
                      ),
                      subtitle: Text('${entry.value} questions'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/mock-test/take?subject=${Uri.encodeComponent(entry.key)}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
