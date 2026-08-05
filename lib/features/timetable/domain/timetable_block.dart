/// Mirrors a `timetable_blocks` row (see `supabase/schema.sql`) — one
/// manually-added study block on the student's personal weekly schedule.
/// `dayOfWeek` follows `DateTime.weekday` (1 = Monday ... 7 = Sunday) so it
/// sorts naturally against real dates later if needed. Times are stored as
/// minutes since midnight (not a `TimeOfDay`, which isn't directly
/// serializable) so blocks sort and format consistently.
class TimetableBlock {
  const TimetableBlock({
    required this.id,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.subject,
    this.done = false,
  });

  final String id;
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
  final String subject;
  final bool done;

  factory TimetableBlock.fromMap(String id, Map<String, dynamic> map) {
    return TimetableBlock(
      id: id,
      dayOfWeek: (map['day_of_week'] as num?)?.toInt() ?? 1,
      startMinutes: (map['start_minutes'] as num?)?.toInt() ?? 0,
      endMinutes: (map['end_minutes'] as num?)?.toInt() ?? 0,
      subject: map['subject'] as String? ?? '',
      done: map['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day_of_week': dayOfWeek,
      'start_minutes': startMinutes,
      'end_minutes': endMinutes,
      'subject': subject,
      'done': done,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  TimetableBlock copyWith({bool? done}) {
    return TimetableBlock(
      id: id,
      dayOfWeek: dayOfWeek,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      subject: subject,
      done: done ?? this.done,
    );
  }

  String get timeRangeLabel =>
      '${_formatMinutes(startMinutes)} – ${_formatMinutes(endMinutes)}';

  static String _formatMinutes(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}

const List<String> weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
