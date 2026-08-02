/// Mirrors `/users/{uid}/syllabusProgress/{topicId}.status`.
enum TopicStatus { notStarted, inProgress, done }

TopicStatus topicStatusFromString(String? value) {
  switch (value) {
    case 'in_progress':
      return TopicStatus.inProgress;
    case 'done':
      return TopicStatus.done;
    default:
      return TopicStatus.notStarted;
  }
}

extension TopicStatusX on TopicStatus {
  String toStorageString() {
    switch (this) {
      case TopicStatus.inProgress:
        return 'in_progress';
      case TopicStatus.done:
        return 'done';
      case TopicStatus.notStarted:
        return 'not_started';
    }
  }

  /// Tapping a topic cycles it forward: not started -> in progress -> done
  /// -> back to not started. A simple three-state tap is faster for a
  /// student to operate than a menu, and still expresses partial progress
  /// (unlike a plain checkbox).
  TopicStatus get next {
    switch (this) {
      case TopicStatus.notStarted:
        return TopicStatus.inProgress;
      case TopicStatus.inProgress:
        return TopicStatus.done;
      case TopicStatus.done:
        return TopicStatus.notStarted;
    }
  }
}
