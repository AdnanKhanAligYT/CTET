import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/models/test_set.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../../profile/application/profile_controller.dart';
import '../../data/exam_catalog_repository.dart';

/// First screen behind both the "Mock Test" and "Previous Year Questions"
/// dashboard tiles — same screen, same data source, just a different
/// [type] so the tree below knows which list of test sets to eventually
/// show. Scoped to the student's own exam selection (profile.exams) —
/// someone preparing only for CTET Paper 1 shouldn't have to wade through
/// every other state's TET here.
///
/// Every level below the exam (paper, subject section, ...) expands
/// in place as a dropdown under its row instead of pushing a new screen —
/// only tapping an actual leaf (no further children) navigates away, into
/// TestSetListScreen. See [_ExamNodeTile].
class ExamListScreen extends ConsumerStatefulWidget {
  const ExamListScreen({super.key, required this.type});

  final TestSetType type;

  @override
  ConsumerState<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends ConsumerState<ExamListScreen> {
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
      final profile = await ref.read(userProfileProvider.future);
      final exams = await _repository.fetchTopLevelExams(
        widget.type,
        allowedNames: profile?.exams,
      );
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
      bottomNavigationBar: const AppBannerAd(),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _exams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aapke chune hue exam(s) ke liye abhi kuch add nahi hua hai.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _exams.length,
                itemBuilder: (context, index) => _ExamNodeTile(
                  node: _exams[index],
                  type: widget.type,
                  repository: _repository,
                  depth: 0,
                ),
              ),
      ),
    );
  }
}

/// One row in the exam/paper/section tree. Tapping it asks "does this node
/// have children?" — if yes, expands a dropdown of them right below (fetched
/// once, then cached for the rest of this screen's life so re-collapsing
/// and re-expanding is instant); if no, it's a leaf, so it navigates
/// straight to that node's test-set list, same destination as before this
/// screen stopped pushing a new page per level.
///
/// A long children list (e.g. a paper's subject sections) only shows the
/// first [_collapsedLimit] up front, with a "View More" row to reveal the
/// rest — the list this replaces (Science(Hin Eng), Social Science, ...)
/// can otherwise be long enough to bury the folder someone actually wants.
class _ExamNodeTile extends StatefulWidget {
  const _ExamNodeTile({
    required this.node,
    required this.type,
    required this.repository,
    required this.depth,
  });

  final ExamNode node;
  final TestSetType type;
  final ExamCatalogRepository repository;
  final int depth;

  @override
  State<_ExamNodeTile> createState() => _ExamNodeTileState();
}

class _ExamNodeTileState extends State<_ExamNodeTile> {
  static const _collapsedLimit = 3;

  bool _expanded = false;
  bool _checkingChildren = false;
  List<ExamNode>? _children;
  bool _showAllChildren = false;

  Future<void> _handleTap() async {
    if (_checkingChildren) return;

    // Already fetched once — just toggle the dropdown, no need to hit the
    // network again.
    if (_children != null) {
      setState(() => _expanded = !_expanded);
      return;
    }

    setState(() => _checkingChildren = true);
    widget.repository.recordExamOpened(widget.node.id);
    try {
      final children = await widget.repository.fetchPapers(
        widget.node.id,
        widget.type,
      );
      if (!mounted) return;
      if (children.isEmpty) {
        // Leaf node — same destination as the old push-based flow.
        setState(() => _checkingChildren = false);
        context.push(
          '/mock-test/sets?type=${widget.type.value}',
          extra: widget.node,
        );
      } else {
        setState(() {
          _children = children;
          _expanded = true;
          _checkingChildren = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingChildren = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    final visibleChildren = children == null
        ? const <ExamNode>[]
        : (_showAllChildren || children.length <= _collapsedLimit)
        ? children
        : children.sublist(0, _collapsedLimit);
    final hasMore =
        children != null &&
        !_showAllChildren &&
        children.length > _collapsedLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: NetworkLogoAvatar(
              url: widget.node.logoUrl,
              fallbackIcon: widget.depth == 0
                  ? Icons.school_outlined
                  : Icons.folder_outlined,
              fallbackColor: AppColors.tileMockTest,
            ),
            title: Text(
              widget.node.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: _checkingChildren
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            enabled: !_checkingChildren,
            onTap: _handleTap,
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in visibleChildren)
                  _ExamNodeTile(
                    node: child,
                    type: widget.type,
                    repository: widget.repository,
                    depth: widget.depth + 1,
                  ),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showAllChildren = true),
                      child: const Text('View More'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
