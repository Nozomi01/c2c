import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/google_sign_in_config.dart';

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

  /// Link phone to the current account (OAuth / email) or update phone (already phone user).
  /// Syncs [users/{uid}.phoneNumber] in Firestore after success.
  Future<void> linkOrUpdatePhoneWithSms({
    required String verificationId,
    required String smsCode,
  });

  /// Link Google to the current user ([linkWithCredential]). Throws if Google is already linked.
  Future<UserCredential> linkGoogleToCurrentUser();

  /// Link Apple to the current user (iOS only). Throws if Apple is already linked.
  Future<UserCredential> linkAppleToCurrentUser();

  Future<UserCredential> signInWithApple();
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithLine();
  Future<UserCredential> signInWithFacebook();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Single instance avoids multiple Pigeon channels; [serverClientId] fixes Android ID token + Firebase Auth.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: kGoogleSignInServerClientId,
  );

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
  Future<void> linkOrUpdatePhoneWithSms({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインが必要です',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      await user.updatePhoneNumber(credential);
    } else {
      await user.linkWithCredential(credential);
    }
    await _auth.currentUser?.reload();
    final phone = _auth.currentUser?.phoneNumber;
    final uid = _auth.currentUser?.uid;
    if (uid != null && phone != null && phone.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'phoneNumber': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<UserCredential> linkGoogleToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインが必要です',
      );
    }
    if (user.providerData.any((p) => p.providerId == 'google.com')) {
      throw FirebaseAuthException(
        code: 'provider-already-linked',
        message: 'Googleは既に連携済みです',
      );
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign_in_aborted',
        message: 'キャンセルされました',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await user.linkWithCredential(credential);
    await cred.user?.reload();
    await _saveGoogleProfileToFirestore(_auth.currentUser, googleUser);
    return cred;
  }

  @override
  Future<UserCredential> linkAppleToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインが必要です',
      );
    }
    if (user.providerData.any((p) => p.providerId == 'apple.com')) {
      throw FirebaseAuthException(
        code: 'provider-already-linked',
        message: 'Appleは既に連携済みです',
      );
    }
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
    final cred = await user.linkWithCredential(oauthCredential);
    await cred.user?.reload();
    return cred;
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
    final googleUser = await _googleSignIn.signIn();
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
    final cred = await _auth.signInWithCredential(credential);
    await _saveGoogleProfileToFirestore(cred.user, googleUser);
    return cred;
  }

  /// Persist Google account profile (displayName, email, photoURL) to Firestore.
  Future<void> _saveGoogleProfileToFirestore(
    User? firebaseUser,
    GoogleSignInAccount googleUser,
  ) async {
    if (firebaseUser == null) return;
    try {
      final displayName = firebaseUser.displayName ?? googleUser.displayName;
      final email = firebaseUser.email ?? googleUser.email;
      final photoURL = firebaseUser.photoURL ?? googleUser.photoUrl?.toString();
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null && displayName.isNotEmpty) data['displayName'] = displayName;
      if (email.isNotEmpty) data['email'] = email;
      if (photoURL != null && photoURL.isNotEmpty) data['photoURL'] = photoURL;
      await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (_) {
      // Non-fatal: Auth user already has profile; Firestore may be updated by onAuthUserCreate
    }
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
    // Prefer HTTP endpoint so LINE login works when App Check fails (e.g. Android emulator).
    String? customToken;
    String? serverError;
    try {
      customToken = await _getLineCustomTokenHttp(accessToken);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      serverError = e is Exception ? e.toString().replaceFirst('Exception: ', '') : null;
    }
    if (customToken != null && customToken.isNotEmpty) {
      final cred = await _auth.signInWithCustomToken(customToken);
      await _applyLineProfileFromFirestore();
      return cred;
    }
    customToken = await _getLineCustomTokenCallable(accessToken);
    if (customToken != null && customToken.isNotEmpty) {
      final cred = await _auth.signInWithCustomToken(customToken);
      await _applyLineProfileFromFirestore();
      return cred;
    }
    throw FirebaseAuthException(
      code: 'line_custom_token_failed',
      message: serverError ?? 'Failed to get Firebase token from LINE. Check Firebase Console → Functions logs for lineCustomTokenHttp.',
    );
  }

  /// LINE custom token via HTTP (no App Check). Works on emulator when attestation fails.
  /// Throws [Exception] with server error message when status is not 200.
  Future<String?> _getLineCustomTokenHttp(String accessToken) async {
    final projectId = Firebase.app().options.projectId;
    final url = Uri.parse(
      'https://asia-northeast1-$projectId.cloudfunctions.net/lineCustomTokenHttp',
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'accessToken': accessToken}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>?;
        return data?['customToken'] as String?;
      }
      String serverError = 'HTTP ${response.statusCode}';
      try {
        final data = jsonDecode(body) as Map<String, dynamic>?;
        final err = data?['error'];
        if (err is String && err.isNotEmpty) serverError = err;
      } catch (_) {}
      throw Exception(serverError);
    } finally {
      client.close();
    }
  }

  /// After LINE sign-in, sync displayName/photoURL from Firestore (filled by Cloud Function from LINE profile).
  Future<void> _applyLineProfileFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return;
      final displayName = data['displayName'] as String?;
      final photoURL = data['photoURL'] as String?;
      if (displayName != null && displayName.isNotEmpty && user.displayName != displayName) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null && photoURL.isNotEmpty && user.photoURL != photoURL) {
        await user.updatePhotoURL(photoURL);
      }
    } catch (_) {
      // Non-fatal: profile will still show from Firestore in UI
    }
  }

  /// LINE custom token via callable (requires App Check).
  Future<String?> _getLineCustomTokenCallable(String accessToken) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
      final response = await functions
          .httpsCallable('createLineCustomToken')
          .call({'accessToken': accessToken});
      return response.data['customToken'] as String?;
    } catch (_) {
      return null;
    }
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

