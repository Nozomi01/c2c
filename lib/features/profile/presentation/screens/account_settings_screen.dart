import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../../core/ui/platform_adaptive.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_mode_provider.dart';
import '../utils/account_link_availability.dart';
import '../utils/account_login_method_ui.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final mode = ref.watch(profileModeProvider);
    final modeNotifier = ref.read(profileModeProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'アカウント設定',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('ログインが必要です'))
          : Builder(
              builder: (context) {
                final linkedMethods =
                    AccountLoginMethodUi.listFromFirebaseUser(user);
                final linkAvailability = AccountLinkAvailability.fromUser(
                  user,
                  applePlatformSupported:
                      defaultTargetPlatform == TargetPlatform.iOS,
                );
                final showLoginSection =
                    linkedMethods.isNotEmpty || linkAvailability.hasAny;
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                  const Text(
                    'マイページの表示',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '購入者向け・出品者向けのメニューと統計を切り替えます',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ProfileMode>(
                    segments: const [
                      ButtonSegment<ProfileMode>(
                        value: ProfileMode.buyer,
                        label: Text('購入者'),
                        icon: Icon(AppIcons.shopping_bag_outlined, size: 18),
                      ),
                      ButtonSegment<ProfileMode>(
                        value: ProfileMode.seller,
                        label: Text('出品者'),
                        icon: Icon(AppIcons.storefront_outlined, size: 18),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (Set<ProfileMode> next) {
                      if (next.isNotEmpty) {
                        modeNotifier.setMode(next.first);
                      }
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.textPrimary;
                        }
                        return AppColors.textSecondary;
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SettingsTile(
                    icon: AppIcons.person_outline,
                    label: 'プロフィール編集',
                    subtitle: '名前・アイコンを変更',
                    onTap: () => context.push('/settings/profile'),
                  ),
                  if (showLoginSection) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'ログイン連携',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      linkedMethods.isEmpty
                          ? 'まだOAuth連携がありません。下から追加できます。電話番号の追加はこの下の「電話番号」から行ってください。'
                          : 'このアカウントに紐づいているログイン方法です。複数登録されている場合はいずれでもログインできます。電話番号の追加・変更は下の「電話番号」から行ってください。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (linkedMethods.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final entry in linkedMethods.asMap().entries) ...[
                        if (entry.key > 0) const SizedBox(height: 8),
                        _SettingsTile(
                          icon: entry.value.icon,
                          label: entry.value.isPrimary
                              ? '${entry.value.label}（メイン）'
                              : entry.value.label,
                          subtitle: entry.value.subtitle,
                          onTap: () {
                            final m = entry.value;
                            showPlatformInfoDialog(
                              context: context,
                              title: m.label,
                              message: m.isPrimary
                                  ? '${m.infoMessage}\n\n※「メイン」はこのアカウントで主なログイン方法として扱われているものです。'
                                  : m.infoMessage,
                            );
                          },
                        ),
                      ],
                    ],
                    if (linkAvailability.hasAny) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '追加できるログイン',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '未連携の方法を追加すると、別の端末や状況でもログインしやすくなります。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (linkAvailability.canAddGoogle)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SettingsTile(
                            icon: AppIcons.g_mobiledata_rounded,
                            label: 'Googleを追加',
                            subtitle: 'Googleアカウントを連携',
                            onTap: () => _runOAuthLink(
                              context,
                              ref,
                              (repo) => repo.linkGoogleToCurrentUser(),
                            ),
                          ),
                        ),
                      if (linkAvailability.canAddApple)
                        _SettingsTile(
                          icon: AppIcons.apple,
                          label: 'Appleを追加',
                          subtitle: 'Appleでサインインを連携',
                          onTap: () => _runOAuthLink(
                            context,
                            ref,
                            (repo) => repo.linkAppleToCurrentUser(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 8),
                  _SettingsTile(
                    icon: AppIcons.phone_android_outlined,
                    label: '電話番号',
                    subtitle: user.phoneNumber ?? '未設定',
                    onTap: () => context.push('/settings/phone'),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await showPlatformAlertDialog<bool>(
                          context: context,
                          title: 'ログアウト',
                          message: 'ログアウトしますか？',
                          cancelText: 'キャンセル',
                          confirmText: 'ログアウト',
                        );
                        if (ok == true && context.mounted) {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) context.go('/');
                        }
                      },
                      icon: const Icon(AppIcons.logout, size: 20),
                      label: const Text('ログアウト'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        // TODO: 退会手続き
                      },
                      child: Text(
                        '退会する',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(AppIcons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _runOAuthLink(
  BuildContext context,
  WidgetRef ref,
  Future<Object?> Function(AuthRepository repo) action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      return PopScope(
        canPop: false,
        child: Center(
          child: isIOS
              ? const CupertinoActivityIndicator(radius: 14)
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
  try {
    final repo = ref.read(authRepositoryProvider);
    await action(repo);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('連携しました')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapAuthLinkError(e))),
      );
    }
  }
}

String _mapAuthLinkError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'credential-already-in-use':
        return 'このログイン先は別のアカウントで使われています。';
      case 'provider-already-linked':
        return e.message ?? '既に連携済みです';
      case 'sign_in_aborted':
        return 'キャンセルされました';
      default:
        return e.message ?? e.code;
    }
  }
  return e.toString();
}
