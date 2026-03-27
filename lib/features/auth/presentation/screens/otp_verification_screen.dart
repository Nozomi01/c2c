import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../providers/auth_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    this.phoneNumber,
  });

  final String verificationId;
  final String? phoneNumber;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    controller.seedVerificationContext(
      verificationId: widget.verificationId,
      phoneNumber: widget.phoneNumber,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('認証コードを入力'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SMSで届いた6桁のコードを入力してください。届かない場合は再送信をお試しください。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '認証コード',
                ),
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return '6桁のコードを入力してください';
                  }
                  return null;
                },
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          await controller.startPhoneVerification(widget.phoneNumber!);
                        },
                  child: const Text('認証コードを再送信'),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          await controller.verifyCode(_codeController.text.trim());
                          final newState =
                              ref.read(phoneAuthControllerProvider);
                          if (!newState.isLoading &&
                              newState.errorMessage == null &&
                              mounted) {
                            context.go('/home');
                          }
                        },
                  child: Text(state.isLoading ? '確認中...' : 'ログイン'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

