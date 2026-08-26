import '../../../core/models/exam_node.dart';

/// [node] is the leaf the Mock Test/PYQ "Syllabus" button was tapped from
/// (e.g. "Science(Hin Eng)") — its own name is what selects its topics
/// (see [resolveSyllabusTopicTags]). [marksExam] is the paper it belongs
/// to (e.g. "CTET Paper 2", see [resolveSyllabusMarksExam]) — that's what
/// selects the marks-distribution table shown above them.
class SyllabusTopicsArgs {
  const SyllabusTopicsArgs({required this.node, required this.marksExam});

  final ExamNode node;
  final String marksExam;
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

class _ParsedSyllabusLeaf {
  const _ParsedSyllabusLeaf(this.subjectTag, this.marksExam);

  final String subjectTag;
  final String marksExam;
}

const _subjectsByKey = {
  'P-1': _ParsedSyllabusLeaf('CTET Paper 1', 'CTET Paper 1'),
  'SCIENCE': _ParsedSyllabusLeaf('CTET Paper 2 Science', 'CTET Paper 2'),
  'SST': _ParsedSyllabusLeaf('CTET Paper 2 SST', 'CTET Paper 2'),
};

/// Decomposes an admin-named Mock Test/PYQ leaf folder (e.g.
/// "Science(Hin Eng)", "SST(Skt Urdu)", "P-1(Eng Urdu)") into the set of
/// `syllabus_topics.exam` tags that make up its content — Child
/// Development & Pedagogy (shared by every leaf), the paper/subject-specific
/// block, and the two chosen languages' Language I / Language II syllabus —
/// rather than requiring every one of the ~36 language-pair leaves to
/// duplicate that content under its own exact name.
///
/// Falls back to `[leafName]` unchanged if it doesn't match the expected
/// "<Subject>(<Lang1> <Lang2>)" naming, so content can still be added
/// directly under a differently-named leaf if the admin ever creates one.
List<String> resolveSyllabusTopicTags(String leafName) {
  final match = _leafPattern.firstMatch(leafName.trim());
  if (match == null) return [leafName];

  final parsed = _subjectsByKey[match.group(1)!.toUpperCase()];
  final lang1 = _languageNames[match.group(2)!.toLowerCase()];
  final lang2 = _languageNames[match.group(3)!.toLowerCase()];
  if (parsed == null || lang1 == null || lang2 == null) return [leafName];

  return [
    'CTET',
    parsed.subjectTag,
    'Language I ($lang1)',
    'Language II ($lang2)',
  ];
}

/// The `syllabus_marks_distribution.exam` tag for [leafName]'s paper (e.g.
/// "CTET Paper 1", "CTET Paper 2") — falls back to [leafName] itself if it
/// doesn't match the expected naming.
String resolveSyllabusMarksExam(String leafName) {
  final match = _leafPattern.firstMatch(leafName.trim());
  if (match == null) return leafName;
  return _subjectsByKey[match.group(1)!.toUpperCase()]?.marksExam ?? leafName;
}
