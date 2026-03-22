import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_theme.dart';
import 'core/config/line_config.dart';
import 'core/router/app_router.dart';
import 'services/firebase/firebase_initializer.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolates.
  await FirebaseInitializer.initialize();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitializer.initialize();

  // Warm up shared_preferences after bindings so the Pigeon channel is ready
  // before any provider reads prefs (avoids channel-error on Android).
  try {
    await SharedPreferences.getInstance();
  } catch (e, st) {
    debugPrint('SharedPreferences warm-up skipped: $e\n$st');
  }

  if (lineChannelId.isNotEmpty) {
    await LineSDK.instance.setup(lineChannelId);
  }

  // Register background message handler for FCM (once per app start).
  // Note: Hot restart re-runs this and can log "Attempted to start a duplicate background isolate" — use full restart to clear.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: WantyApp()));

  // Defer non-critical init (Realtime DB, push notifications, Stripe)
  // so first frame paints sooner and reduces frame drops.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FirebaseInitializer.deferNonCriticalInit();
  });
}

class WantyApp extends ConsumerWidget {
  const WantyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ウォンティ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

