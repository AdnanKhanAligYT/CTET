import 'package:flutter/material.dart';

import '../../../../core/models/exam_node.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/load_error.dart';
import '../../../../core/widgets/network_logo_avatar.dart';
import '../../../mock_test/data/exam_catalog_repository.dart';
import '../syllabus_navigation.dart';

/// Recursive middle screen in the Syllabus flow — mirrors
/// mock_test/presentation/screens/paper_list_screen.dart exactly (same
/// "does this node have children" branch, pushed once per level the admin
/// actually created), just carrying [SyllabusLevelArgs.paperExam] down
/// instead of a Mock Test/PYQ `type`.
class SyllabusLevelScreen extends StatefulWidget {
  const SyllabusLevelScreen({super.key, required this.args});

  final SyllabusLevelArgs args;

  @override
  State<SyllabusLevelScreen> createState() => _SyllabusLevelScreenState();
}

class _SyllabusLevelScreenState extends State<SyllabusLevelScreen> {
  final _repository = ExamCatalogRepository();
  bool _loading = true;
  String? _error;
  List<ExamNode> _children = const [];
  String? _openingId;

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
      final children = await _repository.fetchChildrenForSyllabus(
        widget.args.parent.id,
      );
      if (!mounted) return;
      setState(() {
        _children = children;
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

  Future<void> _open(ExamNode node) async {
    if (_openingId != null) return;
    setState(() => _openingId = node.id);
    try {
      await navigateIntoSyllabusNode(
        context: context,
        repository: _repository,
        node: node,
        paperExam: widget.args.paperExam,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.parent.name;

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
        child: _children.isEmpty
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
                itemCount: _children.length,
                itemBuilder: (context, index) {
                  final node = _children[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: NetworkLogoAvatar(
                        url: node.logoUrl,
                        fallbackIcon: Icons.description_outlined,
                        fallbackColor: AppColors.tileSyllabus,
                      ),
                      title: Text(
                        node.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      trailing: _openingId == node.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      enabled: _openingId == null,
                      onTap: () => _open(node),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
