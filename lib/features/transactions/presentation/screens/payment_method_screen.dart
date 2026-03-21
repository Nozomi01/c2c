import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/presentation/providers/service_detail_provider.dart';
import '../../domain/models/transaction.dart';
import '../providers/transaction_providers.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.transactionId,
    this.clientSecret,
  });

  final String transactionId;
  /// Stripe PaymentIntent client secret from createEscrowPaymentIntent (passed when navigating from purchase confirm).
  final String? clientSecret;

  @override
  ConsumerState<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  int _selectedIndex = 0; // 0: クレジットカード

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionDetailProvider(widget.transactionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('支払い方法'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: txAsync.when(
        data: (tx) {
          final serviceAsync = ref.watch(serviceDetailProvider(tx.serviceId));
          return serviceAsync.when(
            data: (service) => _Content(
              transaction: tx,
              service: service,
              selectedIndex: _selectedIndex,
              onSelectIndex: (i) => setState(() => _selectedIndex = i),
              onPay: () => _submitPayment(context, tx),
              hasStripeSecret: widget.clientSecret != null && widget.clientSecret!.isNotEmpty,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('読み込みに失敗: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みに失敗: $e')),
      ),
    );
  }

  Future<void> _submitPayment(BuildContext context, TransactionModel tx) async {
    final clientSecret = widget.clientSecret;
    if (clientSecret == null || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('支払いを開始できません。購入画面からもう一度お試しください。'),
        ),
      );
      return;
    }
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Wanty',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // 決済成功: 取引ステータスを「支払い済み」に更新
      await ref
          .read(transactionRepositoryProvider)
          .updateStatus(tx.id, TransactionStatus.paid);

      // Notify seller that payment succeeded.
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
        await functions.httpsCallable('sendUserNotification').call({
          'userId': tx.sellerId,
          'title': 'お支払いが完了しました',
          'body': 'お支払いが完了しました。サービス提供を開始してください。',
          'type': 'transaction',
          'extraData': {'transactionId': tx.id},
        });
      } catch (_) {
        // Do not block purchase success flow if notification fails.
      }

      if (!context.mounted) return;
      context.go('/purchase-complete', extra: tx.id);
    } on StripeException catch (e) {
      if (!context.mounted) return;
      if (e.error.code != 'Canceled') {
        final msg = e.error.message ?? '支払いに失敗しました';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('支払いに失敗しました: $msg')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払いの処理に失敗しました: $e')),
      );
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.transaction,
    required this.service,
    required this.selectedIndex,
    required this.onSelectIndex,
    required this.onPay,
    required this.hasStripeSecret,
  });

  final TransactionModel transaction;
  final Service service;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onPay;
  final bool hasStripeSecret;

  @override
  Widget build(BuildContext context) {
    final price = transaction.price;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductCard(service: service),
          const SizedBox(height: 24),
          const Text(
            '支払い方法',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _PaymentOption(
            index: 0,
            selectedIndex: selectedIndex,
            icon: Icons.credit_card,
            label: 'クレジットカード / デビットカード',
            sublabel: hasStripeSecret ? 'Stripeで安全に支払います' : null,
            onTap: () => onSelectIndex(0),
          ),
          if (!hasStripeSecret)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '購入確認画面から再度お進みください。',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _SummaryRow(label: '商品代金', value: '¥${NumberFormat('#,###').format(price)}'),
                const SizedBox(height: 8),
                _SummaryRow(label: '配送料', value: '¥0'),
                const Divider(height: 24),
                _SummaryRow(
                  label: '支払い金額',
                  value: '¥${NumberFormat('#,###').format(price)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasStripeSecret ? onPay : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('支払う'),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: imageUrl == null
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.image, color: AppColors.primary),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.primary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${NumberFormat('#,###').format(service.price)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: selectedIndex,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
