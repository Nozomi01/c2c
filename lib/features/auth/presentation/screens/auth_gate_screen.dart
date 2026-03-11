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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'はじめまして、ウォンティです',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '話したい・相談したい人と、\n気軽につながるマーケットプレイス。',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            _AuthButton(
              icon: Icons.phone_iphone,
              label: '電話番号で始める',
              onPressed: () {
                context.push('/auth/phone');
              },
            ),
            const SizedBox(height: 12),
            const _PlatformSocialButton(),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.chat,
              label: 'LINEで続ける',
              onPressed: () {
                // TODO: LINE login
              },
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.facebook,
              label: 'Facebookで続ける',
              onPressed: () {
                // TODO: Facebook login
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// On iOS shows Apple sign-in, on Android shows Google sign-in.
class _PlatformSocialButton extends ConsumerWidget {
  const _PlatformSocialButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final repo = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (isIOS) {
      return _AuthButton(
        icon: Icons.apple,
        label: 'Appleで続ける',
        onPressed: () async {
          try {
            await repo.signInWithApple();
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Appleログインに失敗しました: $e')),
            );
          }
        },
      );
    }

    return _AuthButton(
      icon: Icons.g_mobiledata_rounded,
      label: 'Googleで続ける',
      onPressed: () async {
        try {
          await repo.signInWithGoogle();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Googleログインに失敗しました: $e')),
          );
        }
      },
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

