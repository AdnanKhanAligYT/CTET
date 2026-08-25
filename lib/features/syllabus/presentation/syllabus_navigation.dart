import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/exam_node.dart';
import '../../mock_test/data/exam_catalog_repository.dart';

/// Which paper (e.g. "CTET Paper 1") the node currently being browsed
/// falls under — this is the exact string stored in
/// `syllabus_topics.exam`/`syllabus_marks_distribution.exam`, so once it's
/// resolved it's carried unchanged all the way down to whichever leaf the
/// student eventually taps.
class SyllabusLevelArgs {
  const SyllabusLevelArgs({required this.parent, required this.paperExam});

  final ExamNode parent;
  final String paperExam;
}

class SyllabusTopicsArgs {
  const SyllabusTopicsArgs({required this.node, required this.paperExam});

  final ExamNode node;
  final String paperExam;
}

/// Shared by SyllabusExamListScreen and SyllabusLevelScreen — same
/// "does this node have children?" branch as the Mock Test/PYQ flow's
/// `navigateIntoExamNode`, except a leaf here opens the full syllabus for
/// [paperExam] instead of a test-set list.
///
/// [paperExam] is null only for the very first tap (out of the top-level
/// exam list, e.g. "CTET") — the node entered right after that becomes the
/// paper itself (e.g. "CTET Paper 1"), so `paperExam ?? node.name` resolves
/// it exactly once and every deeper level just keeps passing it along.
Future<void> navigateIntoSyllabusNode({
  required BuildContext context,
  required ExamCatalogRepository repository,
  required ExamNode node,
  required String? paperExam,
}) async {
  final resolvedPaperExam = paperExam ?? node.name;
  final children = await repository.fetchChildrenForSyllabus(node.id);
  if (!context.mounted) return;
  if (children.isNotEmpty) {
    context.push(
      '/syllabus/level',
      extra: SyllabusLevelArgs(parent: node, paperExam: resolvedPaperExam),
    );
  } else {
    context.push(
      '/syllabus/topics',
      extra: SyllabusTopicsArgs(node: node, paperExam: resolvedPaperExam),
    );
  }
}
