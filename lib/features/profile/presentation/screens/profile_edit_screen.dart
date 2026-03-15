import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_theme.dart';

/// Gender options for profile.
enum ProfileGender {
  unspecified('未選択'),
  male('男性'),
  female('女性'),
  other('その他');

  const ProfileGender(this.label);
  final String label;
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  Uint8List? _avatarBytes;
  bool _saving = false;
  bool _loading = true;
  ProfileGender _gender = ProfileGender.unspecified;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final initialName = user?.displayName ?? user?.email?.split('@').first ?? '';
    _displayNameController = TextEditingController(text: initialName);
    _fullNameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _bioController = TextEditingController();
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
        _fullNameController.text = data['fullName'] as String? ?? '';
        _addressController.text = data['address'] as String? ?? '';
        _phoneController.text =
            (data['phoneNumber'] as String?) ?? user.phoneNumber ?? '';
        _bioController.text = data['bio'] as String? ?? '';
        final g = data['gender'] as String?;
        if (g != null && g.isNotEmpty) {
          _gender = ProfileGender.values.firstWhere(
            (e) => e.name == g,
            orElse: () => ProfileGender.unspecified,
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Widget _avatarEditPlaceholder() {
    return Container(
      width: 96,
      height: 96,
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(Icons.camera_alt, size: 40, color: AppColors.primary),
    );
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
                  padding: const EdgeInsets.all(16),
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
                        _sectionLabel('氏名'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            hintText: '氏名を入力（任意）',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('性別'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ProfileGender>(
                          value: _gender,
                          decoration: const InputDecoration(
                            hintText: '選択してください',
                          ),
                          items: ProfileGender.values
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.label),
                                  ))
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _gender = v);
                                },
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('住所'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            hintText: '住所を入力（任意）',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                        _sectionLabel('電話番号'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '電話番号を入力（任意）',
                          ),
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

      final fullName = _fullNameController.text.trim();
      final address = _addressController.text.trim();
      final phoneNumber = _phoneController.text.trim();
      final bio = _bioController.text.trim();

      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(user.uid).set(
            {
              'displayName': displayName,
              'photoURL': photoUrl,
              'fullName': fullName.isEmpty ? null : fullName,
              'address': address.isEmpty ? null : address,
              'gender': _gender == ProfileGender.unspecified
                  ? null
                  : _gender.name,
              'phoneNumber': phoneNumber.isEmpty ? null : phoneNumber,
              'bio': bio.isEmpty ? null : bio,
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
