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
///
/// The children check is scoped to [type] — a node can be a leaf under
/// one flow and a folder under the other (e.g. its only child is
/// PYQ-only, so it's a leaf when browsing Mock Test but a folder under
/// PYQ), since ExamCatalogRepository.fetchPapers() filters by types too.
Future<void> navigateIntoExamNode({
  required BuildContext context,
  required ExamCatalogRepository repository,
  required ExamNode node,
  required TestSetType type,
}) async {
  repository.recordExamOpened(node.id);
  final children = await repository.fetchPapers(node.id, type);
  if (!context.mounted) return;
  if (children.isNotEmpty) {
    context.push('/mock-test/papers?type=${type.value}', extra: node);
  } else {
    context.push('/mock-test/sets?type=${type.value}', extra: node);
  }
}
