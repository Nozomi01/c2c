import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _bioController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _phoneNumberController;
  late final TextEditingController _locationController;
  late final TextEditingController _skillsController;
  late final TextEditingController _languagesController;
  late final TextEditingController _availabilityController;
  late final TextEditingController _experienceYearsController;
  String _gender = 'unspecified';
  static const _genderOptions = [
    _GenderOption('unspecified', '未設定'),
    _GenderOption('male', '男性'),
    _GenderOption('female', '女性'),
    _GenderOption('other', 'その他'),
  ];

  Uint8List? _avatarBytes;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final initialName = user?.displayName ?? user?.email?.split('@').first ?? '';
    _displayNameController = TextEditingController(text: initialName);
    _hourlyRateController = TextEditingController();
    _bioController = TextEditingController();
    _fullNameController = TextEditingController();
    _birthDateController = TextEditingController();
    _phoneNumberController = TextEditingController(text: user?.phoneNumber ?? '');
    _locationController = TextEditingController();
    _skillsController = TextEditingController();
    _languagesController = TextEditingController();
    _availabilityController = TextEditingController();
    _experienceYearsController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        _displayNameController.text =
            (data['displayName'] as String?) ?? _displayNameController.text;
        final hourlyRate = data['hourlyRate'];
        _hourlyRateController.text = hourlyRate is num ? hourlyRate.toInt().toString() : '';
        _bioController.text = data['bio'] as String? ?? '';
        _fullNameController.text = data['fullName'] as String? ?? '';
        _birthDateController.text = data['birthDate'] as String? ?? '';
        _phoneNumberController.text = data['phoneNumber'] as String? ?? user.phoneNumber ?? '';
        _locationController.text = data['location'] as String? ?? '';
        _skillsController.text = data['skills'] as String? ?? '';
        _languagesController.text = data['languages'] as String? ?? '';
        _availabilityController.text = data['availability'] as String? ?? '';
        final exp = data['experienceYears'];
        _experienceYearsController.text = exp is num ? exp.toInt().toString() : '';
        final g = data['gender'] as String?;
        if (g != null && g.isNotEmpty) {
          _gender = g;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _hourlyRateController.dispose();
    _bioController.dispose();
    _fullNameController.dispose();
    _birthDateController.dispose();
    _phoneNumberController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    _languagesController.dispose();
    _availabilityController.dispose();
    _experienceYearsController.dispose();
    super.dispose();
  }

  Widget _avatarEditPlaceholder() {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(AppIcons.camera_alt, size: 40, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'プロフィール編集',
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
        actions: [
          TextButton(
            onPressed:
                _saving || user == null || _loading ? null : () => _saveProfile(user),
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('ログインが必要です'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _saving ? null : _pickAvatar,
                            child: ClipOval(
                              child: _avatarBytes != null
                                  ? Image.memory(
                                      _avatarBytes!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    )
                                  : (user.photoURL != null &&
                                          user.photoURL!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: user.photoURL!,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _avatarEditPlaceholder(),
                                        )
                                      : _avatarEditPlaceholder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'タップして写真を変更',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('表示名'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            hintText: '表示名を入力',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return '表示名を入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('時給（円）'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _hourlyRateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '例: 5000',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) {
                              return '0以上の数字を入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('自己紹介'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            hintText: '自己紹介を入力（任意）',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('個人情報'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: '氏名',
                            hintText: '例: 山田 花子',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _saving
                              ? null
                              : () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(now.year - 25, now.month, now.day),
                                    firstDate: DateTime(1900, 1, 1),
                                    lastDate: now,
                                  );
                                  if (picked == null) return;
                                  final m = picked.month.toString().padLeft(2, '0');
                                  final d = picked.day.toString().padLeft(2, '0');
                                  _birthDateController.text = '${picked.year}-$m-$d';
                                },
                          decoration: const InputDecoration(
                            labelText: '生年月日',
                            hintText: 'YYYY-MM-DD',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '電話番号',
                            hintText: '例: +81 90 1234 5678',
                          ),
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('詳細情報'),
                        const SizedBox(height: 8),
                        IgnorePointer(
                          ignoring: _saving,
                          child: Opacity(
                            opacity: _saving ? 0.6 : 1,
                            child: DropdownFlutter<_GenderOption>(
                              hintText: '性別',
                              items: _genderOptions,
                              initialItem: _genderOptions.firstWhere(
                                (e) => e.value == _gender,
                                orElse: () => _genderOptions.first,
                              ),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _gender = v.value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: '活動エリア',
                            hintText: '例: 東京都渋谷区 / オンライン可',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _skillsController,
                          decoration: const InputDecoration(
                            labelText: '得意分野',
                            hintText: '例: 恋愛相談, キャリア相談, 英会話',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _languagesController,
                          decoration: const InputDecoration(
                            labelText: '対応言語',
                            hintText: '例: 日本語, 英語',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _availabilityController,
                          decoration: const InputDecoration(
                            labelText: '対応可能時間',
                            hintText: '例: 平日 19:00-23:00',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _experienceYearsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '経験年数',
                            hintText: '例: 3',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) {
                              return '0以上の数字を入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
    });
  }

  Future<void> _saveProfile(User user) async {
    if (!_formKey.currentState!.validate()) return;
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表示名を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl = user.photoURL;

      if (_avatarBytes != null) {
        final storage = FirebaseStorage.instance;
        final ref = storage.ref().child('avatars').child('${user.uid}.jpg');
        await ref.putData(_avatarBytes!);
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }

      if (user.displayName != displayName) {
        await user.updateDisplayName(displayName);
      }

      final hourlyRateText = _hourlyRateController.text.trim();
      final hourlyRate = hourlyRateText.isEmpty ? null : int.tryParse(hourlyRateText);
      final bio = _bioController.text.trim();
      final fullName = _fullNameController.text.trim();
      final birthDate = _birthDateController.text.trim();
      final phoneNumber = _phoneNumberController.text.trim();
      final location = _locationController.text.trim();
      final skills = _skillsController.text.trim();
      final languages = _languagesController.text.trim();
      final availability = _availabilityController.text.trim();
      final experienceYearsText = _experienceYearsController.text.trim();
      final experienceYears = experienceYearsText.isEmpty ? null : int.tryParse(experienceYearsText);

      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(user.uid).set(
            {
              'displayName': displayName,
              'photoURL': photoUrl,
              'hourlyRate': hourlyRate,
              'bio': bio.isEmpty ? null : bio,
              'fullName': fullName.isEmpty ? null : fullName,
              'birthDate': birthDate.isEmpty ? null : birthDate,
              'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
              'gender': _gender == 'unspecified' ? null : _gender,
              'location': location.isEmpty ? null : location,
              'skills': skills.isEmpty ? null : skills,
              'languages': languages.isEmpty ? null : languages,
              'availability': availability.isEmpty ? null : availability,
              'experienceYears': experienceYears,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを保存しました')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _GenderOption {
  const _GenderOption(this.value, this.label);
  final String value;
  final String label;

  @override
  String toString() => label;
}
