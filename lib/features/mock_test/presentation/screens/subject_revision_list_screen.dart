import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/ad_service.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/mock_test_repository.dart';
import '../subject_style.dart';

/// Behind the dashboard's "Subject Wise Revision" tile — the subject list
/// isn't admin-managed, it's derived on the fly from whatever questions
/// already exist, so it always matches the data that's actually been
/// uploaded. Tapping a subject goes to SubjectBlockListScreen. No
/// question count is shown anywhere in this flow (here or on a subject's
/// block list) — the exact size of the question bank per subject
/// shouldn't be something the app hands out.
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
  List<String> _subjects = const [];

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
      final subjects = await _repository.fetchDistinctSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
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
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: const Text('Subject Wise Revision')),
      body: SafeArea(
        child: _subjects.isEmpty
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
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  final style = subjectStyleFor(subject);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color,
                        child: Icon(style.icon, color: Colors.white),
                      ),
                      title: Text(
                        subject,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: style.color,
                            ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/mock-test/subjects/blocks?subject=${Uri.encodeComponent(subject)}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
