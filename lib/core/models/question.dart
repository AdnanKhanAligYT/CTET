/// Mirrors a `/questions/{id}` Firestore document — shared, read-only
/// content written by an internal admin tool, never by the student app
/// (see firestore.rules).
class Question {
  const Question({
    required this.id,
    required this.subject,
    required this.topic,
    required this.examTags,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
    required this.explanations,
  });

  final String id;
  final String subject;
  final String topic;
  final List<String> examTags;
  final String text;
  final List<String> options;
  final int correctOptionIndex;

  /// One explanation per option index — shown instantly after the student
  /// picks an answer, whichever option they chose (matches the reference
  /// PHP mock-test's "instant feedback + explanation" behaviour).
  final List<String> explanations;

  factory Question.fromMap(String id, Map<String, dynamic> map) {
    return Question(
      id: id,
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      examTags:
          (map['exam_tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      text: map['text'] as String? ?? '',
      options:
          (map['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      correctOptionIndex: (map['correct_option_index'] as num?)?.toInt() ?? 0,
      explanations:
          (map['explanations'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  String explanationFor(int optionIndex) {
    if (optionIndex < 0 || optionIndex >= explanations.length) return '';
    return explanations[optionIndex];
  }
}
