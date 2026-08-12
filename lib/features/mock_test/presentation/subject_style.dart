import 'package:flutter/material.dart';

/// A subject's fixed icon + color — same idea as the dashboard's own
/// quick-link tiles (`AppColors.tileMockTest` etc.), one flat color per
/// icon, chosen once and never changing. Used everywhere a subject name
/// is shown in the Subject Wise Revision flow (the subject picker list,
/// the in-test subject chip) so the same subject always reads the same
/// way.
class SubjectStyle {
  const SubjectStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Keyword -> style, most specific first (checked in order, first match
/// wins) — e.g. "Social Science" must match the SST bucket before it ever
/// reaches the generic "science" keyword below it, so admin-entered name
/// variants ("Math" vs "Mathematics", "SST" vs "Social Studies") all land
/// on the one fixed style for that subject.
const _knownSubjectStyles = <(List<String>, SubjectStyle)>[
  (
    ['cdp', 'child development', 'pedagogy'],
    SubjectStyle(icon: Icons.psychology_outlined, color: Color(0xFF7C4DFF)),
  ),
  (
    ['sst', 'social studies', 'social science'],
    SubjectStyle(icon: Icons.public_outlined, color: Color(0xFFE8873C)),
  ),
  (
    ['evs', 'environmental studies', 'environmental science'],
    SubjectStyle(icon: Icons.eco_outlined, color: Color(0xFF12977A)),
  ),
  (
    ['science'],
    SubjectStyle(icon: Icons.science_outlined, color: Color(0xFF15A362)),
  ),
  (
    ['math'],
    SubjectStyle(icon: Icons.calculate_outlined, color: Color(0xFF2F6FED)),
  ),
  (
    ['sanskrit'],
    SubjectStyle(icon: Icons.auto_stories_outlined, color: Color(0xFF8D6E63)),
  ),
  (
    ['hindi'],
    SubjectStyle(icon: Icons.translate_outlined, color: Color(0xFFC2185B)),
  ),
  (
    ['english'],
    SubjectStyle(icon: Icons.menu_book_outlined, color: Color(0xFF4C3FCF)),
  ),
  (
    ['urdu'],
    SubjectStyle(icon: Icons.import_contacts_outlined, color: Color(0xFFB8860B)),
  ),
];

/// Any subject name that doesn't match a known keyword above still gets a
/// fixed icon+color — picked deterministically from the subject's own
/// name (not randomly on every open), so an unrecognised subject looks
/// the same every single time.
const _fallbackPalette = <SubjectStyle>[
  SubjectStyle(icon: Icons.subject_outlined, color: Color(0xFF5C6BC0)),
  SubjectStyle(icon: Icons.book_outlined, color: Color(0xFF26A69A)),
  SubjectStyle(icon: Icons.edit_note_outlined, color: Color(0xFFEF6C00)),
  SubjectStyle(icon: Icons.lightbulb_outline, color: Color(0xFF7CB342)),
  SubjectStyle(icon: Icons.star_outline, color: Color(0xFFAB47BC)),
  SubjectStyle(icon: Icons.bookmark_outline, color: Color(0xFF546E7A)),
];

SubjectStyle subjectStyleFor(String subject) {
  final normalized = subject.toLowerCase().trim();
  for (final (keywords, style) in _knownSubjectStyles) {
    if (keywords.any(normalized.contains)) return style;
  }
  final hash = normalized.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _fallbackPalette[hash % _fallbackPalette.length];
}

/// Question-count "block" size for the exam-wise Mock Test/PYQ checkpoint
/// (see NamedTestScreen) — a purely-visual rest point every N questions
/// within a subject, plus a confirm-to-continue prompt there. SST papers
/// run about double the length of the others, so it gets 60 instead of
/// the default 30.
int chunkSizeForSubject(String subject) {
  final normalized = subject.toLowerCase().trim();
  const sstKeywords = ['sst', 'social studies', 'social science'];
  if (sstKeywords.any(normalized.contains)) return 60;
  return 30;
}
