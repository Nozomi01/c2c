import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();
  Future<void> signOut();

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(FirebaseAuthException e) onError,
  });

  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });

  Future<UserCredential> signInWithApple();
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithLine();
  Future<UserCredential> signInWithFacebook();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(FirebaseAuthException e) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 90),
      verificationCompleted: (credential) async {
        // Auto sign-in when SMS is auto-retrieved (e.g. Android); optional.
      },
      verificationFailed: onError,
      codeSent: (verificationId, [int? _]) => codeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {
        // SMS auto-retrieval timed out; user can still enter code manually.
        // Do not treat as error - codeSent was already called with verificationId.
      },
    );
  }

  @override
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signInWithApple() async {
    // Only supported on Apple platforms; caller should guard on Platform if needed.
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(oauthCredential);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign_in_aborted',
        message: 'Sign in aborted by user',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signInWithLine() async {
    final result = await LineSDK.instance.login();
    final accessToken = result.accessToken.value;
    if (accessToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'line_no_token',
        message: 'LINE login did not return an access token',
      );
    }
    final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
    final response = await functions.httpsCallable('createLineCustomToken').call({'accessToken': accessToken});
    final customToken = response.data['customToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'line_custom_token_failed',
        message: 'Failed to get Firebase token from LINE',
      );
    }
    return _auth.signInWithCustomToken(customToken);
  }

  @override
  Future<UserCredential> signInWithFacebook() {
    throw UnimplementedError('Sign in with Facebook is not implemented yet.');
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

