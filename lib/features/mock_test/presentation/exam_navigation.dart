import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/exam_node.dart';
import '../../../core/models/test_set.dart';
import '../data/exam_catalog_repository.dart';

/// Shared by PaperListScreen (tapping a row) and the dashboard's shortcut
/// tile: checks whether [node] has children first — if so, pushes another
/// list-of-children screen; if it's a leaf, goes straight to its test-set
/// list. Kept as one function so both call sites can't drift apart on what
/// "does this node have children" actually means.
Future<void> navigateIntoExamNode({
  required BuildContext context,
  required ExamCatalogRepository repository,
  required ExamNode node,
  required TestSetType type,
}) async {
  final children = await repository.fetchPapers(node.id);
  if (!context.mounted) return;
  if (children.isNotEmpty) {
    context.push('/mock-test/papers?type=${type.value}', extra: node);
  } else {
    context.push('/mock-test/sets?type=${type.value}', extra: node);
  }
}
