import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/app_icons.dart';

/// One linked sign-in method shown on account settings (multi-provider aware).
class AccountLoginMethodUi {
  const AccountLoginMethodUi({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.infoMessage,
    this.isPrimary = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;

  /// Shown when the user taps the row.
  final String infoMessage;

  /// Firebase treats [User.providerData.first] as the primary provider.
  final bool isPrimary;

  /// OAuth / LINE / password rows only. **Phone is omitted** — the account screen has a
  /// dedicated「電話番号」tile (`/settings/phone`) so we avoid duplicating the number.
  static List<AccountLoginMethodUi> listFromFirebaseUser(User user) {
    final infos = _filteredProviderInfos(user);
    if (infos.isEmpty) {
      return [];
    }
    return [
      for (var i = 0; i < infos.length; i++)
        _fromUserInfo(user, infos[i], isPrimary: i == 0),
    ];
  }

  /// Skip internal `firebase` UID rows when other providers exist, and skip `phone`
  /// (shown separately on account settings).
  static List<UserInfo> _filteredProviderInfos(User user) {
    final list = user.providerData;
    if (list.isEmpty) return [];

    final out = <UserInfo>[];
    for (final info in list) {
      if (info.providerId == 'phone') {
        continue;
      }
      if (info.providerId == 'firebase') {
        if (list.length == 1) {
          out.add(info);
        }
        continue;
      }
      out.add(info);
    }
    return out;
  }

  static AccountLoginMethodUi _fromUserInfo(
    User user,
    UserInfo info, {
    required bool isPrimary,
  }) {
    switch (info.providerId) {
      case 'google.com':
        return AccountLoginMethodUi(
          label: 'Google',
          subtitle: _nonEmpty(info.email) ??
              _nonEmpty(user.email) ??
              '連携済み',
          icon: AppIcons.g_mobiledata_rounded,
          infoMessage:
              'Googleアカウントと連携しています。\n'
              'メールアドレスの変更はGoogleアカウントの設定から行ってください。',
          isPrimary: isPrimary,
        );
      case 'apple.com':
        return AccountLoginMethodUi(
          label: 'Apple',
          subtitle: _nonEmpty(info.email) ??
              _nonEmpty(user.email) ??
              'Apple ID',
          icon: AppIcons.apple,
          infoMessage:
              'Appleでサインインと連携しています。\n'
              'メールの公開はApple IDの設定に従います。',
          isPrimary: isPrimary,
        );
      case 'password':
        return AccountLoginMethodUi(
          label: 'メール / パスワード',
          subtitle: _nonEmpty(info.email) ?? _nonEmpty(user.email) ?? '未設定',
          icon: AppIcons.alternate_email_outlined,
          infoMessage: 'メールアドレスとパスワードでログインしています。変更機能は準備中です。',
          isPrimary: isPrimary,
        );
      case 'facebook.com':
        return AccountLoginMethodUi(
          label: 'Facebook',
          subtitle: _nonEmpty(info.email) ??
              _nonEmpty(user.email) ??
              user.displayName ??
              '連携済み',
          icon: AppIcons.facebook_outlined,
          infoMessage: 'Facebookアカウントと連携しています。',
          isPrimary: isPrimary,
        );
      case 'firebase':
        return AccountLoginMethodUi(
          label: 'LINE',
          subtitle: _nonEmpty(user.displayName) ??
              _nonEmpty(user.email) ??
              'LINEでログイン中',
          icon: AppIcons.chat_bubble_outline,
          infoMessage:
              'LINEアカウント（カスタムトークン）でログインしています。表示名の変更はプロフィール編集から行えます。',
          isPrimary: isPrimary,
        );
      default:
        return AccountLoginMethodUi(
          label: info.providerId,
          subtitle: _nonEmpty(info.email) ??
              _nonEmpty(info.phoneNumber) ??
              _nonEmpty(user.email) ??
              '連携済み',
          icon: AppIcons.link,
          infoMessage: 'このプロバイダーと連携しています。',
          isPrimary: isPrimary,
        );
    }
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
