import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_links.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../providers/auth_providers.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return _AuthLandingScreen();
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

class _AuthLandingScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends ConsumerState<_AuthLandingScreen> {
  bool _termsAccepted = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegalUrl(AppLinks.termsOfServiceUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegalUrl(AppLinks.privacyPolicyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    }
  }

  void _requireTerms(void Function() onAllowed) {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('利用規約とプライバシーポリシーに同意してください。'),
        ),
      );
      return;
    }
    onAllowed();
  }

  Future<void> _requireTermsAsync(Future<void> Function() onAllowed) async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('利用規約とプライバシーポリシーに同意してください。'),
        ),
      );
      return;
    }
    await onAllowed();
  }

  @override
  Widget build(BuildContext context) {
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
                    Colors.white.withValues(alpha: 0.96),
                    Colors.white.withValues(alpha: 0.96),
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
                    icon: AppIcons.facebook,
                    iconColor: const Color(0xFF1877F3), // Facebook blue
                    onPressed: () {
                      _requireTerms(() {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Facebookログインは準備中です'),
                          ),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    _LandingPrimaryButton(
                      label: 'Appleで登録/ログイン',
                      icon: AppIcons.apple,
                      onPressed: () {
                        _requireTermsAsync(() async {
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
                        });
                      },
                    )
                  else
                    _LandingPrimaryButton(
                      label: 'Googleで登録/ログイン',
                      icon: AppIcons.g_mobiledata_rounded,
                      onPressed: () {
                        _requireTermsAsync(() async {
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
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CircleIconButton(
                        color: const Color(0xFFFDC700),
                        icon: AppIcons.phone_iphone,
                        onTap: () {
                          _requireTerms(() {
                            context.push('/auth/phone');
                          });
                        },
                      ),
                      const SizedBox(width: 24),
                      _CircleIconButton(
                        color: const Color(0xFF06C755),
                        icon: AppIcons.chat_bubble,
                        onTap: () {
                          _requireTermsAsync(() async {
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
                          });
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _termsAccepted,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) {
                                setState(() {
                                  _termsAccepted = v ?? false;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                  text: '次に進むと、',
                                ),
                                TextSpan(
                                  text: '利用規約',
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: _termsTap,
                                ),
                                const TextSpan(text: 'と'),
                                TextSpan(
                                  text: 'プライバシーポリシー',
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: _privacyTap,
                                ),
                                const TextSpan(
                                  text: 'に同意することになります。',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            borderRadius: BorderRadius.circular(AppRadii.jumbo),
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
      borderRadius: BorderRadius.circular(AppRadii.xxxl),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}

