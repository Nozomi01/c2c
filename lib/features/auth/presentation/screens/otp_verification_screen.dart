import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
  });

  final String verificationId;

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
    // Ensure controller has the verification ID when opening directly.
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final state = ref.read(phoneAuthControllerProvider);
    if (state.verificationId == null) {
      controller.state = controller.state
          .copyWith(verificationId: widget.verificationId);
    }
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
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SMSで届いた6桁のコードを入力してください。',
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

