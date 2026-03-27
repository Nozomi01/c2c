import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

class PhoneAuthState {
  const PhoneAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.verificationId,
    this.lastVerifiedPhoneNumber,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? verificationId;
  final String? lastVerifiedPhoneNumber;

  PhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
    String? lastVerifiedPhoneNumber,
  }) {
    return PhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      verificationId: verificationId ?? this.verificationId,
      lastVerifiedPhoneNumber: lastVerifiedPhoneNumber ?? this.lastVerifiedPhoneNumber,
    );
  }
}

class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  PhoneAuthController(this._read) : super(const PhoneAuthState());

  final Ref _read;

  AuthRepository get _repo => _read.read(authRepositoryProvider);

  Future<void> startPhoneVerification(String phoneNumber) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      lastVerifiedPhoneNumber: phoneNumber,
    );
    await _repo.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      codeSent: (verificationId) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verificationId,
        );
      },
      onError: (e) {
        final message = _userFriendlyAuthError(e);
        state = state.copyWith(
          isLoading: false,
          errorMessage: message,
        );
      },
    );
  }

  Future<void> verifyCode(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(errorMessage: '検証IDがありません。もう一度お試しください。');
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.signInWithSmsCode(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? e.code,
      );
    }
  }

  /// SMS確認後、ログインせず現在のアカウントに電話番号を紐付け／変更する。
  Future<void> verifyCodeAndUpdatePhone(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(errorMessage: '検証IDがありません。もう一度お試しください。');
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.linkOrUpdatePhoneWithSms(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _userFriendlyPhoneUpdateError(e),
      );
    }
  }

  void reset() {
    state = const PhoneAuthState();
  }

  void seedVerificationContext({
    required String verificationId,
    String? phoneNumber,
  }) {
    final shouldSeed = state.verificationId == null || state.verificationId!.isEmpty;
    if (!shouldSeed) return;
    state = state.copyWith(
      verificationId: verificationId.isNotEmpty ? verificationId : null,
      lastVerifiedPhoneNumber: phoneNumber ?? state.lastVerifiedPhoneNumber,
    );
  }
}

String _userFriendlyPhoneUpdateError(FirebaseAuthException e) {
  final code = e.code.toLowerCase();
  if (code.contains('credential-already-in-use')) {
    return 'この電話番号は別のアカウントで使われています。';
  }
  if (code.contains('invalid-verification-code')) {
    return '認証コードが正しくありません。';
  }
  if (code.contains('session-expired')) {
    return '認証の有効期限が切れました。もう一度送信してください。';
  }
  return e.message ?? e.code;
}

final phoneAuthControllerProvider =
    StateNotifierProvider<PhoneAuthController, PhoneAuthState>((ref) {
  return PhoneAuthController(ref);
});

String _userFriendlyAuthError(FirebaseAuthException e) {
  final code = e.code.toLowerCase();
  final msg = e.message ?? e.code;
  if (code.contains('recaptcha') || code.contains('captcha')) {
    return '認証の準備ができません。実機でお試しになるか、しばらく経ってから再度お試しください。';
  }
  if (code.contains('too-many-requests')) {
    return 'リクエストが多すぎます。しばらく経ってから再度お試しください。';
  }
  if (code.contains('invalid-phone')) {
    return '電話番号の形式が正しくありません。国番号から入力してください。';
  }
  return msg;
}

