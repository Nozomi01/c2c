import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// アカウント設定から電話番号を紐付け／変更する（ログインフローとは別）。
class PhoneNumberEditScreen extends ConsumerStatefulWidget {
  const PhoneNumberEditScreen({super.key});

  @override
  ConsumerState<PhoneNumberEditScreen> createState() =>
      _PhoneNumberEditScreenState();
}

class _PhoneNumberEditScreenState extends ConsumerState<PhoneNumberEditScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _otpStep = false;
  late String _pendingPhoneE164;

  /// Captured while [context] is valid — do not use [ref] in [dispose].
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    final phone = ref.read(authStateProvider).valueOrNull?.phoneNumber;
    _phoneController.text =
        (phone != null && phone.isNotEmpty) ? phone : '+81';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(phoneAuthControllerProvider.notifier).reset();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    _container?.read(phoneAuthControllerProvider.notifier).reset();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (prev, next) {
      if (!_otpStep &&
          next.verificationId != null &&
          prev?.verificationId != next.verificationId) {
        setState(() {
          _otpStep = true;
          _pendingPhoneE164 = next.lastVerifiedPhoneNumber ?? _phoneController.text.trim();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            if (_otpStep) {
              setState(() {
                _otpStep = false;
                _codeController.clear();
                controller.reset();
              });
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _otpStep ? '認証コードを入力' : '電話番号の変更',
          style: const TextStyle(
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _otpStep
            ? _buildOtpStep(context, state, controller)
            : _buildPhoneStep(context, state, controller),
      ),
    );
  }

  Widget _buildPhoneStep(
    BuildContext context,
    PhoneAuthState state,
    PhoneAuthController controller,
  ) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SMSで認証コードをお送りします。国番号から入力してください（例: +81 90 1234 5678）。',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '電話番号',
              hintText: '+81 90 1234 5678',
              border: OutlineInputBorder(),
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
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      if (!_phoneFormKey.currentState!.validate()) return;
                      _pendingPhoneE164 = _phoneController.text.trim();
                      await controller.startPhoneVerification(_pendingPhoneE164);
                    },
              child: Text(state.isLoading ? '送信中...' : '認証コードを送信'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(
    BuildContext context,
    PhoneAuthState state,
    PhoneAuthController controller,
  ) {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_pendingPhoneE164 に送信しました。\n6桁のコードを入力してください。',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '認証コード',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().length != 6) {
                return '6桁のコードを入力してください';
              }
              return null;
            },
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          TextButton(
            onPressed: state.isLoading
                ? null
                : () async {
                    await controller.startPhoneVerification(_pendingPhoneE164);
                  },
            child: const Text('認証コードを再送信'),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      if (!_otpFormKey.currentState!.validate()) return;
                      await controller.verifyCodeAndUpdatePhone(
                        _codeController.text.trim(),
                      );
                      final after = ref.read(phoneAuthControllerProvider);
                      if (!after.isLoading &&
                          after.errorMessage == null &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('電話番号を更新しました')),
                        );
                        context.pop();
                      }
                    },
              child: Text(state.isLoading ? '確認中...' : '確定'),
            ),
          ),
        ],
      ),
    );
  }
}
