import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../providers/profile_mode_provider.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final mode = ref.watch(profileModeProvider);
    final modeNotifier = ref.read(profileModeProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        icon: Icon(Icons.shopping_bag_outlined, size: 18),
                      ),
                      ButtonSegment<ProfileMode>(
                        value: ProfileMode.seller,
                        label: Text('出品者'),
                        icon: Icon(Icons.storefront_outlined, size: 18),
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
                    icon: Icons.person_outline,
                    label: 'プロフィール編集',
                    subtitle: '名前・アイコンを変更',
                    onTap: () => context.push('/settings/profile'),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.email_outlined,
                    label: 'メールアドレス',
                    subtitle: user.email ?? '未設定',
                    onTap: () {
                      // TODO: メール変更
                    },
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.phone_android_outlined,
                    label: '電話番号',
                    subtitle: user.phoneNumber ?? '未設定',
                    onTap: () {
                      // TODO: 電話番号変更
                    },
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    label: 'パスワード変更',
                    subtitle: '••••••••',
                    onTap: () {
                      // TODO: パスワード変更（メール/電話認証の場合の再設定）
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('ログアウト'),
                            content: const Text('ログアウトしますか？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('ログアウト'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) context.go('/');
                        }
                      },
                      icon: const Icon(Icons.logout, size: 20),
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
