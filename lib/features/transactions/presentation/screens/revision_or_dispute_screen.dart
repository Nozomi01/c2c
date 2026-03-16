import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_theme.dart';

class RevisionOrDisputeScreen extends ConsumerStatefulWidget {
  const RevisionOrDisputeScreen({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<RevisionOrDisputeScreen> createState() =>
      _RevisionOrDisputeScreenState();
}

class _RevisionOrDisputeScreenState
    extends ConsumerState<RevisionOrDisputeScreen> {
  String _selected = 'revision'; // revision or dispute
  final _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_detailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容を入力してください')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      // TODO: Firestore に revision / dispute の内容を保存する
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected == 'revision'
                ? '修正依頼を送信しました'
                : '問題報告を送信しました',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送信に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '受取に関する相談',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'どのような対応を希望しますか？',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: 'revision',
                groupValue: _selected,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selected = v);
                },
                activeColor: AppColors.primary,
                title: const Text('修正を依頼したい'),
                subtitle: const Text(
                  '内容の一部修正や追加対応をお願いしたい場合はこちらを選択してください。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              RadioListTile<String>(
                value: 'dispute',
                groupValue: _selected,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selected = v);
                },
                activeColor: AppColors.primary,
                title: const Text('問題を報告したい（返金・トラブル）'),
                subtitle: const Text(
                  'サービス内容が大きく異なるなど、運営による確認が必要な場合はこちらを選択してください。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selected == 'revision' ? '依頼したい修正内容' : '問題の内容',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: _selected == 'revision'
                      ? 'どの部分をどのように修正してほしいか、できるだけ具体的に記入してください。'
                      : 'どのような問題が発生しているか、いつ・どこで・どのように起きたかを記入してください。',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '修正依頼・問題報告の内容は、出品者および運営が確認します。'
                  'チャットも併用しながら、円滑な解決にご協力ください。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF856404),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(_submitting ? '送信中...' : '送信する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

