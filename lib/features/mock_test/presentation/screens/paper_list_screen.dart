import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/widgets/load_error.dart';
import '../../data/exam_catalog_repository.dart';

/// Second screen in the Mock Test / PYQ flow — papers under one exam
/// (e.g. tapping "CTET" shows "CTET Paper 1", "CTET Paper 2").
class PaperListScreen extends StatefulWidget {
  const PaperListScreen({super.key, required this.parent, required this.type});

  final ExamNode parent;
  final TestSetType type;

  @override
  State<PaperListScreen> createState() => _PaperListScreenState();
}

class _PaperListScreenState extends State<PaperListScreen> {
  final _repository = ExamCatalogRepository();
  bool _loading = true;
  String? _error;
  List<ExamNode> _papers = const [];

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
      final papers = await _repository.fetchPapers(widget.parent.id);
      if (!mounted) return;
      setState(() {
        _papers = papers;
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.parent.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.parent.name)),
        body: LoadError(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.parent.name)),
      body: SafeArea(
        child: _papers.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Is exam ke paper abhi add nahi hue.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _papers.length,
                itemBuilder: (context, index) {
                  final paper = _papers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(paper.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/mock-test/sets?type=${widget.type.value}',
                        extra: paper,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
