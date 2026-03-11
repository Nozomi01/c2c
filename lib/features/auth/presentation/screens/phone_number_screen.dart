import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '+81');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('電話番号でログイン'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SMSで認証コードをお送りします。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  hintText: '+81 90 1234 5678',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '電話番号を入力してください';
                  }
                  if (!v.trim().startsWith('+')) {
                    return '国番号を含めて入力してください（例: +81）';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                          await controller
                              .startPhoneVerification(_phoneController.text.trim());
                          final verificationId =
                              ref.read(phoneAuthControllerProvider).verificationId;
                          if (verificationId != null && mounted) {
                            context.push(
                              '/auth/phone/verify',
                              extra: verificationId,
                            );
                          }
                        },
                  child: Text(state.isLoading ? '送信中...' : '認証コードを送信'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

