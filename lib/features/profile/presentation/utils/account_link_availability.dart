import 'package:firebase_auth/firebase_auth.dart';

/// Which OAuth providers can still be [linkWithCredential]'d onto this account.
/// Phone is added via the dedicated「電話番号」row, not here (avoids duplicate UI).
class AccountLinkAvailability {
  const AccountLinkAvailability({
    required this.canAddGoogle,
    required this.canAddApple,
  });

  final bool canAddGoogle;
  final bool canAddApple;

  bool get hasAny => canAddGoogle || canAddApple;

  static bool _hasProvider(User user, String providerId) {
    return user.providerData.any((p) => p.providerId == providerId);
  }

  static AccountLinkAvailability fromUser(
    User user, {
    required bool applePlatformSupported,
  }) {
    return AccountLinkAvailability(
      canAddGoogle: !_hasProvider(user, 'google.com'),
      canAddApple:
          applePlatformSupported && !_hasProvider(user, 'apple.com'),
    );
  }
}
