/// A Mock Test attempt's live state while it's being taken — kept
/// entirely on-device (see MockTestLocalStore), never synced to Supabase
/// question-by-question. Only the final aggregate (score/rank/percentile)
/// is written to `attempts` once, at submit time, to keep the app's
/// Supabase usage light. Losing this (app data cleared, different device)
/// just means the attempt can't be resumed — a fresh one starts instead.
class MockTestSession {
  const MockTestSession({
    required this.testSetId,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.answers,
    required this.flagged,
    required this.visited,
  });

  final String testSetId;
  final DateTime startedAt;
  final int elapsedSeconds;

  /// question_id -> selected option index.
  final Map<String, int> answers;

  /// question_id set, "marked for review" (independent of whether answered).
  final Set<String> flagged;

  /// question_id set, ever opened — distinguishes "Not Visited" (grey) from
  /// "Not Answered" (red) in the navigator.
  final Set<String> visited;

  MockTestSession copyWith({
    int? elapsedSeconds,
    Map<String, int>? answers,
    Set<String>? flagged,
    Set<String>? visited,
  }) {
    return MockTestSession(
      testSetId: testSetId,
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      answers: answers ?? this.answers,
      flagged: flagged ?? this.flagged,
      visited: visited ?? this.visited,
    );
  }

  factory MockTestSession.fresh(String testSetId) => MockTestSession(
    testSetId: testSetId,
    startedAt: DateTime.now(),
    elapsedSeconds: 0,
    answers: const {},
    flagged: const {},
    visited: const {},
  );

  factory MockTestSession.fromJson(Map<String, dynamic> json) {
    return MockTestSession(
      testSetId: json['testSetId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      answers: ((json['answers'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(key as String, (value as num).toInt()),
      ),
      flagged: ((json['flagged'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      visited: ((json['visited'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
    'testSetId': testSetId,
    'startedAt': startedAt.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'answers': answers,
    'flagged': flagged.toList(),
    'visited': visited.toList(),
  };
}
