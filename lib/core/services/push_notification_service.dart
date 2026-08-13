import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:url_launcher/url_launcher.dart';

import '../routing/app_router.dart';
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

    // Tapped while the app was backgrounded (not killed).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigateForData(message.data),
    );
    // App was cold-started by tapping the notification — the message
    // that launched it, if any.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _navigateForData(initialMessage.data);

    // Tapped while shown as a local notification (the foreground-display
    // path below, or one of NotificationService's own reminders — those
    // never set a payload, so this is a no-op for them).
    NotificationService.onNotificationTapped = (payload) {
      try {
        _navigateForData(jsonDecode(payload) as Map<String, dynamic>);
      } catch (_) {
        // Malformed/unexpected payload — nothing to navigate to.
      }
    };
  }

  /// Reads the admin-set "tap action" out of an FCM message's `data`
  /// payload (set by ctet_content_admin.php's Notification tab) and acts
  /// on it. Every value in FCM `data` arrives as a String, so this can
  /// never trust types beyond that. Unknown/missing `action` — including
  /// every one of NotificationService's local reminders, which never set
  /// one — is a deliberate no-op: the app just opens to wherever it
  /// already was.
  static void _navigateForData(Map<String, dynamic> data) {
    switch (data['action']) {
      case 'mock_test':
        appRouter.push('/mock-test');
      case 'test':
        final id = data['test_set_id'] as String?;
        if (id != null && id.isNotEmpty) {
          appRouter.push('/mock-test/open?id=${Uri.encodeComponent(id)}');
        }
      case 'url':
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
    }
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
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }
}
