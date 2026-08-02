import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Client-side half of the reminders system (streak nudges, due-review
/// alerts, timetable pings, weekly summary — see `functions/index.js` for
/// the scheduled Cloud Functions that actually send these). This service
/// only handles: asking for permission, keeping the device's FCM token
/// saved on the student's profile so a Cloud Function can target it, and
/// showing a system notification when a push arrives while the app is
/// open (FCM doesn't display foreground notifications on its own).
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

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission();

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Whenever someone signs in (fresh login, or an already-logged-in
    // session resuming), make sure this device's token is on their
    // profile — cheap to repeat, and covers the token having rotated.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveTokenForUser(user.uid);
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _saveToken(uid, token);
    });
  }

  static Future<void> _saveTokenForUser(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) {
    // A student may be logged in on more than one device, so tokens are
    // an (deduplicated) set rather than a single field.
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
