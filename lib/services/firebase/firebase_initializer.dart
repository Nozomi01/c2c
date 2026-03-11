import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
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

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

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

      // Stripe basic setup (publishable key should be set via env/config)
      try {
        Stripe.publishableKey = StripeConfig.publishableKey;
        Stripe.merchantIdentifier = 'wanty.app';
        await Stripe.instance.applySettings();
      } catch (e, st) {
        debugPrint('Stripe initialization error: $e\n$st');
        // Don't crash the app if Stripe fails to initialize.
      }
    } catch (e, st) {
      debugPrint('Firebase initialization error: $e\n$st');
      rethrow;
    }
  }
}

class StripeConfig {
  // For security this should be injected from env at runtime.
  static const publishableKey = 'pk_test_REPLACE_WITH_YOUR_KEY';
}

