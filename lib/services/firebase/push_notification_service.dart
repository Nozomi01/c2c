import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Simple FCM push notification setup.
///
/// - Requests notification permission (iOS / Android 13+).
/// - Stores the FCM token under users/{uid}.fcmTokens.
/// - Sets up basic foreground/onMessage logging.
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Ask for permission (required on iOS, recommended on Android 13+).
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    // Get token and save to the current user's Firestore document.
    await _updateToken();

    // Also handle token refresh.
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refreshed: $token');
      await _saveTokenToUser(token);
    });

    // Foreground messages (app open) – for now just log.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM onMessage: ${message.messageId} '
          'title=${message.notification?.title} '
          'body=${message.notification?.body}');
    });

    // When user taps a notification and opens the app.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
      // TODO: Navigate to specific screen based on message.data if needed.
    });
  }

  static Future<void> _updateToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM token: $token');
      if (token != null) {
        await _saveTokenToUser(token);
      }
    } catch (e, st) {
      debugPrint('Error getting FCM token: $e\n$st');
    }
  }

  static Future<void> _saveTokenToUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final users = FirebaseFirestore.instance.collection('users');
    final docRef = users.doc(user.uid);

    await docRef.set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

