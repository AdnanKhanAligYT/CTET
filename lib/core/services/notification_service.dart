import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Displays admin-sent push notifications (see PushNotificationService)
/// as a local notification when the app is in the foreground — Android/
/// iOS don't auto-show a system notification for an FCM message that
/// arrives while the app is already open, so this is what makes a
/// foreground push actually visible.
///
/// There used to also be a whole set of on-device scheduled reminders
/// here (due-reviews, streak, weekly summary, motivational quotes, exam
/// countdown, timetable blocks) — removed entirely. Anything in that
/// spirit now goes out as an actual admin-sent push instead (see
/// ctet_content_admin.php's Notification tab's quick-send templates).
class NotificationService {
  NotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Set by PushNotificationService at startup — lets a tapped admin
  /// push's deep-link payload (JSON-encoded `{"action": ..., ...}`) reach
  /// the router without this local-notification layer needing to know
  /// anything about routes.
  static void Function(String payload)? onNotificationTapped;

  static const _channel = AndroidNotificationChannel(
    'default_channel',
    'General',
    description: 'Study reminders and updates',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Shows an already-initialized local notification immediately — used
  /// by PushNotificationService to display an admin-sent push while the
  /// app is in the foreground. Reuses this same plugin instance/channel
  /// rather than standing up a second one.
  static Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) {
    return _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: payload,
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
}
