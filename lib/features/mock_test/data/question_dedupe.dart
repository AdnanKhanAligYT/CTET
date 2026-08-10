import '../../../core/models/question.dart';

/// Drops questions whose text is identical (exact match, after trimming)
/// to one already kept — a data-entry duplicate re-uploaded under a
/// different id would otherwise appear twice in Subject Wise Revision.
/// Keeps the first occurrence, same order otherwise.
List<Question> dedupeByText(List<Question> questions) {
  final seenText = <String>{};
  final deduped = <Question>[];
  for (final question in questions) {
    if (seenText.add(question.text.trim())) deduped.add(question);
  }
  return deduped;
}
