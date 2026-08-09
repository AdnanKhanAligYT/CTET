import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../data/exam_catalog_repository.dart';

/// Recursive middle screen in the Mock Test / PYQ flow — children of one
/// exam node (e.g. tapping "CTET" shows "CTET Paper 1", "CTET Paper 2";
/// tapping "CTET Paper 2" might show "Science", "Social Science" sections
/// if the admin added a level there, or go straight to the test-set list
/// if it didn't). The `exams` table's parent_exam_id is a plain
/// self-reference with no depth limit, so this same screen pushes another
/// instance of itself for as many levels as the admin actually created —
/// each tap just asks "does this node have children?" and branches.
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
  // Id of the row whose children are currently being checked on tap (only
  // one at a time) — used to disable the rest of the list and show a small
  // spinner in place of that row's chevron while the check is in flight.
  String? _checkingId;

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

  // Tapping a row: check whether IT has further children — if so, push
  // another level of this same screen; if not, it's a leaf, so go straight
  // to that node's test-set list (the old, only behaviour before this
  // screen supported more than 2 levels).
  Future<void> _open(ExamNode node) async {
    if (_checkingId != null) return;
    setState(() => _checkingId = node.id);
    try {
      final children = await _repository.fetchPapers(node.id);
      if (!mounted) return;
      if (children.isNotEmpty) {
        context.push(
          '/mock-test/papers?type=${widget.type.value}',
          extra: node,
        );
      } else {
        context.push('/mock-test/sets?type=${widget.type.value}', extra: node);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _checkingId = null);
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
                      leading: NetworkLogoAvatar(
                        url: paper.logoUrl,
                        fallbackIcon: Icons.description_outlined,
                        fallbackColor: AppColors.tileMockTest,
                      ),
                      title: Text(
                        paper.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      trailing: _checkingId == paper.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      enabled: _checkingId == null,
                      onTap: () => _open(paper),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
