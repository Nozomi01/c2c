import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_theme.dart';

class IdentityVerifyScreen extends StatefulWidget {
  const IdentityVerifyScreen({super.key});

  @override
  State<IdentityVerifyScreen> createState() => _IdentityVerifyScreenState();
}

class _IdentityVerifyScreenState extends State<IdentityVerifyScreen> {
  String _status = 'unverified'; // unverified / pending / verified
  bool _loading = true;
  bool _submitting = false;
  Uint8List? _idImageBytes;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _status = 'unverified';
        _loading = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final status = (data['identityStatus'] as String?) ?? 'unverified';
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '本人確認',
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
      body: user == null
          ? const Center(child: Text('ログインが必要です'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusChip(),
                      const SizedBox(height: 16),
                      const Text(
                        '本人確認とは？',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '安全にサービスを利用いただくために、顔写真付きの公的身分証による本人確認をお願いしています。',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '利用できる身分証の例',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '・運転免許証\n・マイナンバーカード\n・パスポート（顔写真ページ）',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_status == 'unverified') ...[
                        const Text(
                          '身分証の写真をアップロード',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _submitting ? null : _pickIdImage,
                          child: Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.7),
                              ),
                            ),
                            child: _idImageBytes == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.credit_card,
                                          size: 40,
                                          color: AppColors.textSecondary),
                                      SizedBox(height: 8),
                                      Text(
                                        'タップして身分証の写真を選択',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _idImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_status == 'unverified') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _submitting ? null : () => _startVerification(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('本人確認を開始する'),
                          ),
                        ),
                      ] else if (_status == 'pending') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '提出済みの書類を審査中です。しばらくお待ちください。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ] else if (_status == 'verified') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '本人確認が完了しています。安心してサービスをご利用いただけます。',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusChip() {
    late String label;
    late Color color;

    switch (_status) {
      case 'verified':
        label = '本人確認済み';
        color = Colors.green;
        break;
      case 'pending':
        label = '審査中';
        color = Colors.orange;
        break;
      default:
        label = '未確認';
        color = AppColors.textSecondary;
    }

    return Row(
      children: [
        const Text(
          '現在のステータス: ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickIdImage() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      // If no camera is available (e.g. emulator), fall back to gallery.
      if (e.code == 'no_available_camera') {
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラの起動に失敗しました: ${e.message ?? e.code}')),
        );
        return;
      }
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _idImageBytes = bytes;
    });
  }

  Future<void> _startVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_idImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('身分証の写真をアップロードしてください')),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      // Upload ID card image to Storage.
      final storage = FirebaseStorage.instance;
      final ref =
          storage.ref().child('identity').child('${user.uid}_idcard.jpg');
      await ref.putData(_idImageBytes!);
      final url = await ref.getDownloadURL();

      // Save status and image URL in Firestore.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'identityStatus': 'pending',
          'identitySubmittedAt': FieldValue.serverTimestamp(),
          'identityImageUrl': url,
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      setState(() {
        _status = 'pending';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('本人確認の申請を受け付けました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('申請に失敗しました: $e'),
        ),
      );
      setState(() {
        _status = 'unverified';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

