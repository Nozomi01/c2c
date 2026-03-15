import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../providers/auth_providers.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const _AuthLandingScreen();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/home');
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('認証エラー: $e')),
      ),
    );
  }
}

class _AuthLandingScreen extends ConsumerWidget {
  const _AuthLandingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_background.png',
              fit: BoxFit.cover,
              // If the background asset is missing, fall back to plain white
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.96),
                    Colors.white.withOpacity(0.96),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 100,
                      ),
                      const SizedBox(height: 16),
                      Image.asset(
                        'assets/images/logo_text.png',
                        height: 40,
                      ),
                    ],
                  ),
                  const Spacer(),
                  _LandingPrimaryButton(
                    label: 'Facebookで登録/ログイン',
                    icon: Icons.facebook,
                    iconColor: const Color(0xFF1877F3), // Facebook blue
                    onPressed: () {
                      // TODO: Facebook login
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Facebookログインは準備中です'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    _LandingPrimaryButton(
                      label: 'Appleで登録/ログイン',
                      icon: Icons.apple,
                      onPressed: () async {
                        try {
                          await repo.signInWithApple();
                          if (context.mounted) context.go('/home');
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Appleログインに失敗しました: $e'),
                            ),
                          );
                        }
                      },
                    )
                  else
                    _LandingPrimaryButton(
                      label: 'Googleで登録/ログイン',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: () async {
                        try {
                          await repo.signInWithGoogle();
                          if (context.mounted) context.go('/home');
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Googleログインに失敗しました: $e'),
                            ),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CircleIconButton(
                        color: const Color(0xFFFDC700),
                        icon: Icons.phone_iphone,
                        onTap: () {
                          context.push('/auth/phone');
                        },
                      ),
                      const SizedBox(width: 24),
                      _CircleIconButton(
                        color: const Color(0xFF06C755),
                        icon: Icons.chat_bubble,
                        onTap: () async {
                          try {
                            await repo.signInWithLine();
                            if (context.mounted) context.go('/home');
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('LINEログインに失敗しました: $e'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: 0.7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.check_box_outline_blank,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '次に進むと、利用規約とプライバシーポリシーに同意することになります。',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPrimaryButton extends StatelessWidget {
  const _LandingPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor ?? Colors.black87),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}

