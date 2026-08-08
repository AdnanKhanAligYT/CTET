/// A `test_sets` row is either a Mock Test or a Previous Year Questions
/// set — both are named, reusable, retake-as-many-times-as-you-like
/// tests under a paper (an [ExamNode] whose parentExamId is not null).
/// The only structural difference is [type], which just decides which
/// list (Mock Test vs PYQ) a set shows up in.
enum TestSetType { mockTest, pyq }

extension TestSetTypeX on TestSetType {
  String get value => this == TestSetType.mockTest ? 'mock_test' : 'pyq';

  static TestSetType fromValue(String? value) =>
      value == 'pyq' ? TestSetType.pyq : TestSetType.mockTest;
}

/// Mirrors a `test_sets` row (see `supabase/schema.sql`).
class TestSet {
  const TestSet({
    required this.id,
    required this.examId,
    required this.type,
    required this.types,
    required this.name,
    required this.logoUrl,
    required this.subjects,
    required this.timeLimitMinutes,
    required this.year,
    required this.sortOrder,
  });

  final String id;
  final String examId;
  final TestSetType type;

  /// Every list this set shows up in (see [TestSetRepository.fetchTestSets])
  /// — usually just [type], but the admin tool's "+ ... mein bhi dikhao"
  /// button can cross-list the same set (same tagged questions) into both
  /// Mock Test and PYQ at once.
  final List<TestSetType> types;
  final String name;

  /// Admin-uploaded PNG/JPG/WebP (Supabase Storage, public bucket) shown
  /// before the test's name in the list — null means "show the default
  /// icon instead" (see TestSetListScreen).
  final String? logoUrl;

  /// Ordered subject tabs the test screen walks through sequentially by
  /// default (manual tab switch always allowed) — e.g. ["Hindi", "English"].
  final List<String> subjects;

  final int? timeLimitMinutes;

  /// Previous Year Questions only; null for mock_test sets.
  final int? year;

  final int sortOrder;

  factory TestSet.fromMap(Map<String, dynamic> map) {
    final type = TestSetTypeX.fromValue(map['type'] as String?);
    final typesRaw = (map['types'] as List?)?.map((e) => e.toString()).toList();
    return TestSet(
      id: map['id'] as String,
      examId: map['exam_id'] as String,
      type: type,
      types: (typesRaw == null || typesRaw.isEmpty)
          ? [type]
          : typesRaw.map(TestSetTypeX.fromValue).toList(),
      name: map['name'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
      subjects:
          (map['subjects'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      timeLimitMinutes: (map['time_limit_minutes'] as num?)?.toInt(),
      year: (map['year'] as num?)?.toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
