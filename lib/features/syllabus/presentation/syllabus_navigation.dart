import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/exam_node.dart';
import '../../mock_test/data/exam_catalog_repository.dart';

class SyllabusLevelArgs {
  const SyllabusLevelArgs({required this.parent});

  final ExamNode parent;
}

/// [node] is the leaf the student tapped all the way down to (e.g.
/// "Science(Hin Eng)") — its own name is what selects its topics (see
/// [resolveSyllabusTopicTags]). [marksExam] is the name of the leaf's
/// immediate parent folder (e.g. "CTET Paper 2") — that's what selects
/// the marks-distribution table shown above them, since the wrapper
/// folders above a leaf (like the top-level "CTET") aren't meaningful
/// `syllabus_marks_distribution.exam` tags on their own.
class SyllabusTopicsArgs {
  const SyllabusTopicsArgs({required this.node, required this.marksExam});

  final ExamNode node;
  final String marksExam;
}

/// Shared by SyllabusExamListScreen and SyllabusLevelScreen — same
/// "does this node have children?" branch as the Mock Test/PYQ flow's
/// `navigateIntoExamNode`, except a leaf here opens the full syllabus for
/// itself instead of a test-set list.
///
/// [marksExamFallback] is the name of the folder currently being browsed
/// (i.e. the screen [node] was tapped from) — used only if [node] turns
/// out to be a leaf, becoming that leaf's marks-table exam. Passing it in
/// this way (rather than threading a single resolved value down through
/// every level) means the marks table always resolves to whichever folder
/// *directly* contains the leaf, no matter how many wrapper levels (e.g.
/// "CTET" -> "CTET Paper 2") sit above it.
Future<void> navigateIntoSyllabusNode({
  required BuildContext context,
  required ExamCatalogRepository repository,
  required ExamNode node,
  required String marksExamFallback,
}) async {
  final children = await repository.fetchChildrenForSyllabus(node.id);
  if (!context.mounted) return;
  if (children.isNotEmpty) {
    context.push('/syllabus/level', extra: SyllabusLevelArgs(parent: node));
  } else {
    context.push(
      '/syllabus/topics',
      extra: SyllabusTopicsArgs(node: node, marksExam: marksExamFallback),
    );
  }
}

const _languageNames = {
  'hin': 'Hindi',
  'eng': 'English',
  'skt': 'Sanskrit',
  'urdu': 'Urdu',
};

final _leafPattern = RegExp(
  r'^(P-1|Science|SST)\s*\(\s*([A-Za-z]+)\s+([A-Za-z]+)\s*\)$',
  caseSensitive: false,
);

/// Decomposes an admin-named Syllabus leaf folder (e.g. "Science(Hin Eng)",
/// "SST(Skt Urdu)", "P-1(Eng Urdu)") into the set of `syllabus_topics.exam`
/// tags that make up its content — Child Development & Pedagogy (shared by
/// every leaf), the paper/subject-specific block, and the two chosen
/// languages' Language I / Language II syllabus — rather than requiring
/// every one of the ~36 language-pair leaves to duplicate that content
/// under its own exact name.
///
/// Falls back to `[leafName]` unchanged if it doesn't match the expected
/// "<Subject>(<Lang1> <Lang2>)" naming, so content can still be added
/// directly under a differently-named leaf if the admin ever creates one.
List<String> resolveSyllabusTopicTags(String leafName) {
  final match = _leafPattern.firstMatch(leafName.trim());
  if (match == null) return [leafName];

  final subjectKey = match.group(1)!.toUpperCase();
  final lang1 = _languageNames[match.group(2)!.toLowerCase()];
  final lang2 = _languageNames[match.group(3)!.toLowerCase()];
  if (lang1 == null || lang2 == null) return [leafName];

  final subjectTag = switch (subjectKey) {
    'P-1' => 'CTET Paper 1',
    'SCIENCE' => 'CTET Paper 2 Science',
    'SST' => 'CTET Paper 2 SST',
    _ => leafName,
  };

  return ['CTET', subjectTag, 'Language I ($lang1)', 'Language II ($lang2)'];
}
