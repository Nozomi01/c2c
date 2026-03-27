import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple FCM push notification setup.
///
/// - Requests notification permission (iOS / Android 13+).
/// - Stores the FCM token under users/{uid}.fcmTokens.
/// - Sets up basic foreground/onMessage logging.
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for incoming chat messages',
    importance: Importance.high,
  );
  static bool _initialized = false;
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  static bool _pushEnabled = true;

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

    // Create notification channel and local notification config.
    await _initLocalNotifications();

    // Get token and save to the current user's Firestore document.
    await _updateToken();

    // If user logs in after app launch, persist token for that user as well.
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      await _userSub?.cancel();
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
        final data = snap.data() ?? <String, dynamic>{};
        _pushEnabled = data['pushEnabled'] as bool? ?? true;
      });
      await _updateToken();
    });

    // Also handle token refresh.
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refreshed: $token');
      await _saveTokenToUser(token);
    });

    // Foreground messages: also show local notification so users can see it.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('FCM onMessage: ${message.messageId} '
          'title=${message.notification?.title} '
          'body=${message.notification?.body}');
      await _showForegroundNotification(message);
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

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings: initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_pushEnabled) return;
    final title = message.notification?.title;
    final body = message.notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for incoming chat messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? '新しいメッセージ',
      body: body ?? '',
      notificationDetails: details,
      payload: message.data['chatId'] as String?,
    );
  }
}

