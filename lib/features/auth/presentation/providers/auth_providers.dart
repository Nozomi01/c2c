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
  });

  final bool isLoading;
  final String? errorMessage;
  final String? verificationId;

  PhoneAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
  }) {
    return PhoneAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

class PhoneAuthController extends StateNotifier<PhoneAuthState> {
  PhoneAuthController(this._read) : super(const PhoneAuthState());

  final Ref _read;

  AuthRepository get _repo => _read.read(authRepositoryProvider);

  Future<void> startPhoneVerification(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _repo.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      codeSent: (verificationId) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verificationId,
        );
      },
      onError: (e) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.message ?? e.code,
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
}

final phoneAuthControllerProvider =
    StateNotifierProvider<PhoneAuthController, PhoneAuthState>((ref) {
  return PhoneAuthController(ref);
});

