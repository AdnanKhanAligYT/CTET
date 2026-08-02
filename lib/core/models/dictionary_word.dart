/// Mirrors a `/dictionaryWords/{id}` Firestore document — shared,
/// read-only vocabulary content (see firestore.rules).
class DictionaryWord {
  const DictionaryWord({
    required this.id,
    required this.word,
    required this.meaningHi,
    required this.meaningEn,
    this.exampleSentence = '',
  });

  final String id;
  final String word;
  final String meaningHi;
  final String meaningEn;
  final String exampleSentence;

  factory DictionaryWord.fromMap(String id, Map<String, dynamic> map) {
    return DictionaryWord(
      id: id,
      word: map['word'] as String? ?? '',
      meaningHi: map['meaningHi'] as String? ?? '',
      meaningEn: map['meaningEn'] as String? ?? '',
      exampleSentence: map['exampleSentence'] as String? ?? '',
    );
  }
}
