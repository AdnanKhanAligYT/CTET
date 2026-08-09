import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/primary_button.dart';
import '../../../profile/application/profile_controller.dart';
import '../../data/mock_test_repository.dart';
import '../subject_style.dart';

/// Behind the dashboard's "Subject Wise Revision" tile — the subject list
/// isn't admin-managed, it's derived on the fly from whatever questions
/// already exist (for the student's selected exams), so it always matches
/// the data that's actually been uploaded. Tapping a subject jumps
/// straight into TakeTestScreen for that subject.
class SubjectRevisionListScreen extends ConsumerStatefulWidget {
  const SubjectRevisionListScreen({super.key});

  @override
  ConsumerState<SubjectRevisionListScreen> createState() =>
      _SubjectRevisionListScreenState();
}

class _SubjectRevisionListScreenState
    extends ConsumerState<SubjectRevisionListScreen> {
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

      final questions = await _repository.fetchQuestionsForExams(exams);
      final counts = <String, int>{};
      for (final question in questions) {
        if (question.subject.isEmpty) continue;
        counts[question.subject] = (counts[question.subject] ?? 0) + 1;
      }
      final entries = counts.entries.toList()
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
