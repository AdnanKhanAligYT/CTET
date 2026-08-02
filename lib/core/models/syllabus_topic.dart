/// Mirrors a `/syllabusTopics/{id}` Firestore document — shared, read-only
/// content (see firestore.rules); `order` controls display order within a
/// subject.
class SyllabusTopic {
  const SyllabusTopic({
    required this.id,
    required this.exam,
    required this.subject,
    required this.unit,
    required this.topicName,
    required this.order,
    this.estimatedHours,
  });

  final String id;
  final String exam;
  final String subject;
  final String unit;
  final String topicName;
  final int order;
  final double? estimatedHours;

  factory SyllabusTopic.fromMap(String id, Map<String, dynamic> map) {
    return SyllabusTopic(
      id: id,
      exam: map['exam'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      topicName: map['topicName'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      estimatedHours: (map['estimatedHours'] as num?)?.toDouble(),
    );
  }
}
