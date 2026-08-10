import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'notification_service.dart';

/// Admin-sent push notifications (the Study-App admin tool's
/// Notification tab) — distinct from NotificationService's fixed local
/// reminders, which need no server round trip at all. This one needs a
/// device token saved somewhere the admin tool can read it (the
/// `device_tokens` Supabase table) and a foreground handler, since
/// Android/iOS don't auto-show a system notification for a message that
/// arrives while the app is already open.
class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging.requestPermission();
    } catch (_) {
      // No google-services.json yet, or permission dialog unavailable —
      // same fail-open stance as the rest of this app's optional
      // integrations (see AdService/FirebaseMessaging init in main.dart):
      // the student just won't get push notifications until it's set up.
      return;
    }

    await _saveTokenIfSignedIn();
    _messaging.onTokenRefresh.listen((_) => _saveTokenIfSignedIn());

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  static Future<void> _saveTokenIfSignedIn() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client.from('device_tokens').upsert({
        'token': token,
        'user_id': uid,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-fatal — worst case this device just doesn't receive the next
      // admin broadcast until the token is saved on a later app open.
    }
  }

  /// Call once right after a student signs in (see HomeGate) — the token
  /// above may have been fetched before login (uid was null then), so
  /// nothing got saved; this re-runs the save now that we have a uid.
  static Future<void> onSignedIn() => _saveTokenIfSignedIn();

  static Future<void> _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null || notification.title == null) {
      return Future.value();
    }
    return NotificationService.showNow(
      title: notification.title!,
      body: notification.body ?? '',
    );
  }
}
