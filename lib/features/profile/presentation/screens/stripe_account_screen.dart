import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';

class StripeAccountScreen extends ConsumerStatefulWidget {
  const StripeAccountScreen({super.key});

  @override
  ConsumerState<StripeAccountScreen> createState() => _StripeAccountScreenState();
}

class _StripeAccountScreenState extends ConsumerState<StripeAccountScreen> {
  bool _loading = false;

  /// Fetches Stripe Connect account link URL via HTTP (no App Check), avoiding "1 out of 2 underlying tasks failed" from callable.
  Future<String?> _fetchStripeConnectUrl() async {
    return _fetchStripeConnectUrlHttp();
  }

  Future<String?> _fetchStripeConnectUrlHttp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    String? idToken;
    try {
      idToken = await user.getIdToken(true);
    } catch (_) {
      return null;
    }
    if (idToken == null || idToken.isEmpty) return null;

    final projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) return null;

    final url = Uri.parse(
      'https://asia-northeast1-$projectId.cloudfunctions.net/createStripeConnectAccountLinkHttp',
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $idToken');
      request.write('{}');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        String serverMessage = 'URLの取得に失敗しました';
        try {
          final data = jsonDecode(body) as Map<String, dynamic>?;
          final err = data?['error'];
          if (err is String && err.isNotEmpty) serverMessage = err;
        } catch (_) {}
        throw Exception(serverMessage);
      }
      final data = jsonDecode(body) as Map<String, dynamic>?;
      return data?['url'] as String?;
    } on SocketException {
      rethrow;
    } on IOException {
      rethrow;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool _isNetworkError(Object e) {
    return e is SocketException ||
        e is IOException ||
        e.toString().toLowerCase().contains('host lookup') ||
        e.toString().contains('No address associated');
  }

  Future<void> _startStripeOnboarding() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? url = await _fetchStripeConnectUrl();
      if (url == null || url.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('URLの取得に失敗しました。ログインし直すか、しばらくしてから再試行してください。'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      bool launched = false;
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      } catch (e) {
        // launchUrl can throw (e.g. "1 out of 2 underlying tasks failed" on some Android setups).
        if (mounted) {
          await Clipboard.setData(ClipboardData(text: url));
          messenger.showSnackBar(
            SnackBar(
              content: Text('ブラウザを開けませんでした。URLをコピーしました: $e'),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
        return;
      }

      if (mounted && launched) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ブラウザでStripeの画面を開きました。完了したらアプリに戻ってください。'),
          ),
        );
      } else if (!launched && mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('URLを開けませんでした。URLをコピーしました。ブラウザに貼り付けて開いてください。'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on SocketException catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('インターネットに接続できません。Wi‑Fiまたはモバイルデータをオンにしてから再試行してください。'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on IOException catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('インターネットに接続できません。Wi‑Fiまたはモバイルデータをオンにしてから再試行してください。'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        final msg = e.message ?? e.code;
        messenger.showSnackBar(
          SnackBar(content: Text('エラー: $msg'), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (mounted) {
        final isNetwork = _isNetworkError(e);
        String display = isNetwork
            ? 'インターネットに接続できません。Wi‑Fiまたはモバイルデータをオンにしてから再試行してください。'
            : (e.toString().startsWith('Exception: ')
                ? e.toString().substring('Exception: '.length)
                : 'エラー: $e');
        messenger.showSnackBar(
          SnackBar(content: Text(display), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Stripeアカウント連携',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.account_balance_wallet, size: 40, color: AppColors.primary),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '売上金を受け取るには、Stripeアカウントの連携が必要です。',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '連携の流れ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _StepRow(number: 1, text: '「Stripeと連携する」をタップ'),
            const SizedBox(height: 8),
            _StepRow(number: 2, text: 'Stripeの画面でアカウント作成またはログイン'),
            const SizedBox(height: 8),
            _StepRow(number: 3, text: '本人確認・口座情報を入力'),
            const SizedBox(height: 8),
            _StepRow(number: 4, text: '審査完了後、売上金の出金が可能になります'),
            const SizedBox(height: 40),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _startStripeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Stripeと連携する'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stripeの利用規約とプライバシーポリシーに同意の上、ご利用ください。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
