import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:c2c/firebase_options.dart';

/// Realtime Database URL. Create a database in Firebase Console (Build → Realtime Database),
/// then copy the URL here (e.g. https://<projectId>-default-rtdb.<region>.firebaseio.com).
/// If null, Realtime Database is not used.
const String? _realtimeDatabaseUrl = 'https://wanty-d606b-default-rtdb.asia-southeast1.firebaseio.com';

class FirebaseInitializer {
  static FirebaseDatabase? _database;

  /// Firebase Realtime Database instance, or null if not configured. Call after [initialize].
  static FirebaseDatabase? get database => _database;

  /// Set to true in debug to use Auth Emulator (run: firebase emulators:start --only auth).
  /// Avoids reCAPTCHA/Play Integrity on emulator. Use 10.0.2.2 on Android emulator for localhost.
  static const bool useAuthEmulator = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // App Check: use debug provider in debug mode to satisfy token and reduce console warnings.
      // On first run, register the printed debug token in Firebase Console → App Check → Manage debug tokens.
      if (kDebugMode) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          );
        } catch (e, st) {
          debugPrint('App Check activate error (non-fatal): $e\n$st');
        }
      }

      // Optional: use Auth Emulator in debug to avoid reCAPTCHA/Play Integrity on emulator.
      if (kDebugMode && useAuthEmulator) {
        try {
          // Android emulator: use 10.0.2.2 for host machine localhost.
          await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
        } catch (e, st) {
          debugPrint('Auth emulator connect error: $e\n$st');
        }
      }

      // Defer heavy/optional init to after first frame (call deferNonCriticalInit() from main).
    } catch (e, st) {
      debugPrint('Firebase initialization error: $e\n$st');
      rethrow;
    }
  }

  /// Call after runApp (e.g. in WidgetsBinding.instance.addPostFrameCallback) to avoid blocking first frame.
  static Future<void> deferNonCriticalInit() async {
    if (_realtimeDatabaseUrl != null && _realtimeDatabaseUrl!.isNotEmpty) {
      try {
        _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: _realtimeDatabaseUrl!,
        );
      } catch (e, st) {
        debugPrint('Realtime Database init error: $e\n$st');
      }
    }
    try {
      Stripe.publishableKey = StripeConfig.publishableKey;
      Stripe.merchantIdentifier = 'wanty.app';
      await Stripe.instance.applySettings();
    } catch (e, st) {
      debugPrint('Stripe initialization error: $e\n$st');
    }
  }
}

class StripeConfig {
  // For security this should be injected from env at runtime.
  static const publishableKey = 'pk_test_REPLACE_WITH_YOUR_KEY';
}

