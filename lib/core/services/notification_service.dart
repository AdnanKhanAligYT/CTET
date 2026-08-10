import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/timetable/domain/timetable_block.dart';

/// Local-only reminders. There is no server component anymore (see
/// README "Reminders" — the old Firebase Cloud Functions were dropped
/// along with the rest of Firebase): every reminder here is scheduled
/// entirely on-device with `flutter_local_notifications`, using
/// `zonedSchedule`'s daily/weekly repeat matching instead of a server cron
/// job. All times assume IST, since every exam this app supports is
/// India-only.
class NotificationService {
  NotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'default_channel',
    'General',
    description: 'Study reminders and updates',
    importance: Importance.high,
  );

  static const _dueReviewsNotificationId = 1000;
  static const _weeklySummaryNotificationId = 1001;
  static const _dailyGoalNotificationId = 1002;
  static const _streakNotificationId = 1003;
  // Timetable blocks get ids starting here, one per block, so
  // rescheduling can cancel exactly the old set without touching the
  // fixed ids above.
  static const _timetableNotificationIdBase = 2000;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _scheduleDueReviewsReminder();
    await _scheduleWeeklySummaryReminder();
    await _scheduleDailyGoalReminder();
    await _scheduleStreakReminder();
  }

  /// Daily nudge — kept as a fixed 8 AM prompt rather than a live due-count
  /// (that would need a database round trip on every app start just to
  /// keep one notification's text current); tapping it takes the student
  /// to Mock Test / Dictionary same as before.
  static Future<void> _scheduleDueReviewsReminder() async {
    await _localNotifications.zonedSchedule(
      id: _dueReviewsNotificationId,
      title: 'Revision due today',
      body: 'Check Mock Test and Dictionary for items waiting to be reviewed.',
      scheduledDate: _nextInstanceOf(hour: 8, minute: 0),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleWeeklySummaryReminder() async {
    await _localNotifications.zonedSchedule(
      id: _weeklySummaryNotificationId,
      title: 'Your week in review',
      body: 'See how your mock test scores went this week in History.',
      scheduledDate: _nextInstanceOf(hour: 19, minute: 0, weekday: DateTime.sunday),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Afternoon nudge toward the student's daily practice target — same
  /// fixed-text, always-fires approach as the reminders above (no per-user
  /// progress lookup, so it's honest either way: a student who already hit
  /// their goal just sees an extra tap-through, not a wrong number).
  static Future<void> _scheduleDailyGoalReminder() async {
    await _localNotifications.zonedSchedule(
      id: _dailyGoalNotificationId,
      title: 'Aaj ka target pura hua?',
      body: 'Thodi der nikaal ke aaj ka practice goal pura kar lo.',
      scheduledDate: _nextInstanceOf(hour: 13, minute: 0),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Late-evening last-chance nudge so a day doesn't slip by with zero
  /// practice.
  static Future<void> _scheduleStreakReminder() async {
    await _localNotifications.zonedSchedule(
      id: _streakNotificationId,
      title: 'Apna streak mat todo!',
      body: 'Agar aaj abhi tak practice nahi kiya, toh ek test abhi kar lo.',
      scheduledDate: _nextInstanceOf(hour: 21, minute: 0),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Re-syncs the timetable reminders to exactly the blocks passed in —
  /// call this whenever the student's timetable changes (after add/toggle
  /// /delete). Each block gets one recurring weekly notification 10
  /// minutes before it starts.
  static Future<void> scheduleTimetableReminders(
    List<TimetableBlock> blocks,
  ) async {
    // Clear the old set first so a deleted block's reminder doesn't linger.
    for (var i = 0; i < 200; i++) {
      await _localNotifications.cancel(id: _timetableNotificationIdBase + i);
    }
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final reminderMinutes = block.startMinutes - 10;
      if (reminderMinutes < 0) continue;
      await _localNotifications.zonedSchedule(
        id: _timetableNotificationIdBase + i,
        title: 'Time to study',
        body: '${block.subject} starts in 10 minutes.',
        scheduledDate: _nextInstanceOf(
          hour: reminderMinutes ~/ 60,
          minute: reminderMinutes % 60,
          weekday: block.dayOfWeek,
        ),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Shows an already-initialized local notification immediately — used
  /// by PushNotificationService to display an admin-sent push while the
  /// app is in the foreground (Android/iOS don't auto-show a system
  /// notification for a foreground FCM message the way they do when the
  /// app is backgrounded/terminated). Reuses this same plugin
  /// instance/channel rather than standing up a second one.
  static Future<void> showNow({required String title, required String body}) {
    return _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _details(),
    );
  }

  static NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  /// Next occurrence of [hour]:[minute] IST, optionally pinned to a
  /// specific [weekday] (`DateTime.weekday`-style, 1 = Monday .. 7 =
  /// Sunday). Used as the anchor moment for a repeating `zonedSchedule` —
  /// the `matchDateTimeComponents` argument at each call site is what
  /// actually makes it recur.
  static tz.TZDateTime _nextInstanceOf({
    required int hour,
    required int minute,
    int? weekday,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (weekday != null) {
      while (scheduled.weekday != weekday) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(
        Duration(days: weekday != null ? 7 : 1),
      );
    }
    return scheduled;
  }
}
