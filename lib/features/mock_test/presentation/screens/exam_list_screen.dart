import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/exam_catalog_repository.dart';

/// First screen behind both the "Mock Test" and "Previous Year Questions"
/// dashboard tiles — same screen, same data source, just a different
/// [type] so the next screen (PaperListScreen -> TestSetListScreen) knows
/// which list of test sets to eventually show.
class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key, required this.type});

  final TestSetType type;

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final _repository = ExamCatalogRepository();
  bool _loading = true;
  String? _error;
  List<ExamNode> _exams = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exams = await _repository.fetchTopLevelExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == TestSetType.mockTest
        ? 'Mock Test'
        : 'Previous Year Questions';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: LoadError(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _exams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Abhi koi exam add nahi hua hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _exams.length,
                itemBuilder: (context, index) {
                  final exam = _exams[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(exam.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/mock-test/papers?type=${widget.type.value}',
                        extra: exam,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
