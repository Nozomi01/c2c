import 'dart:io';
import 'dart:typed_data';

import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../domain/models/service.dart';
import '../providers/service_list_provider.dart';

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

enum _DeliveryMode { onlineOnly, offlineOnly, both }

enum _ScheduleMode { consult, specify }

class _ScheduleEntry {
  const _ScheduleEntry({required this.date, required this.timeSlots});
  final DateTime date;
  final List<String> timeSlots;
}

class _CategoryItem {
  const _CategoryItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DurationOption {
  const _DurationOption(this.minutes, this.label);
  final int minutes;
  final String label;
  @override
  String toString() => label;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _DurationOption && minutes == other.minutes;
  @override
  int get hashCode => minutes.hashCode;
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController(text: '東京都');
  int _duration = 60;
  String _category = 'トーク・雑談';
  _DeliveryMode _deliveryMode = _DeliveryMode.both;
  _ScheduleMode _scheduleMode = _ScheduleMode.specify;
  static const _durationOptions = [30, 60, 90, 120];
  final List<XFile> _imageFiles = [];
  static const _maxImages = 10;
  DateTime? _selectedDate;
  final List<String> _selectedTimeSlots = [];
  final List<_ScheduleEntry> _scheduleEntries = [];

  static const _timeSlots = [
    '09:00 - 10:00',
    '10:00 - 11:00',
    '11:00 - 12:00',
    '12:00 - 13:00',
    '13:00 - 14:00',
    '14:00 - 15:00',
    '15:00 - 16:00',
    '16:00 - 17:00',
    '17:00 - 18:00',
    '18:00 - 19:00',
  ];

  static const _categories = [
    _CategoryItem('トーク・雑談', AppIcons.chat_bubble_outline),
    _CategoryItem('相談・アドバイス', AppIcons.lightbulb_outline),
    _CategoryItem('カフェ・ご飯', AppIcons.restaurant_outlined),
    _CategoryItem('趣味・遊び', AppIcons.sports_esports_outlined),
    _CategoryItem('お出かけ・同行', AppIcons.person_outline),
    _CategoryItem('その他', AppIcons.star_border),
  ];

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '${minutes}分';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}時間';
    return '${h}時間${m}分';
  }

  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _online => _deliveryMode == _DeliveryMode.onlineOnly || _deliveryMode == _DeliveryMode.both;
  bool get _offline => _deliveryMode == _DeliveryMode.offlineOnly || _deliveryMode == _DeliveryMode.both;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(serviceRepositoryProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('新規出品'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('ログインが必要です'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品画像
                    const Text('商品画像', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._imageFiles.asMap().entries.map((e) {
                          final i = e.key;
                          final xFile = e.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: _buildImageThumbnail(xFile),
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _imageFiles.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(AppIcons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        if (_imageFiles.length < _maxImages)
                          InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(AppIcons.add_photo_alternate, size: 28, color: Colors.grey.shade600),
                                  const SizedBox(height: 4),
                                  Text('追加', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('最大$_maxImages枚まで追加できます', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),

                    // タイトル
                    const Text('タイトル*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: '例: 気軽にお話しましょう!',
                      ),
                      validator: (v) => v == null || v.isEmpty ? '必須です' : null,
                    ),
                    const SizedBox(height: 16),

                    // カテゴリ
                    const Text('カテゴリ*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: _categories.map((item) {
                        final isSelected = _category == item.label;
                        return InkWell(
                          onTap: () => setState(() => _category = item.label),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primarySoft : Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 価格・時間
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('価格*', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '¥ ',
                                  hintText: '5000',
                                ),
                                validator: (v) => v == null || v.isEmpty ? '必須です' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('時間', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              DropdownFlutter<_DurationOption>(
                                hintText: '時間を選択',
                                items: _durationOptions
                                    .map((m) => _DurationOption(m, _durationLabel(m)))
                                    .toList(),
                                initialItem: _DurationOption(_duration, _durationLabel(_duration)),
                                onChanged: (value) {
                                  if (value != null) setState(() => _duration = value.minutes);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 実施形式
                    const Text('実施形式*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChip('オンラインのみ', _deliveryMode == _DeliveryMode.onlineOnly, () => setState(() => _deliveryMode = _DeliveryMode.onlineOnly)),
                        const SizedBox(width: 8),
                        _buildChip('対面のみ', _deliveryMode == _DeliveryMode.offlineOnly, () => setState(() => _deliveryMode = _DeliveryMode.offlineOnly)),
                        const SizedBox(width: 8),
                        _buildChip('両方可能', _deliveryMode == _DeliveryMode.both, () => setState(() => _deliveryMode = _DeliveryMode.both)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 実施場所
                    const Text('実施場所', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(hintText: '東京都'),
                    ),
                    const SizedBox(height: 16),

                    // 実施日程
                    const Text('実施日程', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildScheduleChip('相談して決める', _scheduleMode == _ScheduleMode.consult, () => setState(() => _scheduleMode = _ScheduleMode.consult)),
                        const SizedBox(width: 8),
                        _buildScheduleChip('日程を指定する', _scheduleMode == _ScheduleMode.specify, () => setState(() => _scheduleMode = _ScheduleMode.specify)),
                      ],
                    ),
                    if (_scheduleMode == _ScheduleMode.specify) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('日付', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            _buildTapField(
                              value: _selectedDate != null
                                  ? DateFormat('y/M/d').format(_selectedDate!)
                                  : null,
                              hint: '日付を選択',
                              icon: AppIcons.calendar_today,
                              onTap: () => _showDatePickerBottomSheet(context),
                            ),
                            const SizedBox(height: 12),
                            const Text('時間帯', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            _buildTapField(
                              value: _selectedTimeSlots.isEmpty ? null : _selectedTimeSlots.first,
                              hint: '時間帯を選択',
                              icon: AppIcons.access_time,
                              onTap: () => _showTimeSlotBottomSheet(context),
                            ),
                            if (_selectedTimeSlots.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _selectedTimeSlots.map((slot) {
                                  return Chip(
                                    label: Text(slot, style: const TextStyle(fontSize: 12)),
                                    deleteIcon: const Icon(AppIcons.close, size: 16),
                                    onDeleted: () => setState(() => _selectedTimeSlots.remove(slot)),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildGreyOutlinedButton(
                              icon: AppIcons.add,
                              label: '時間帯を追加',
                              onPressed: () => _showTimeSlotBottomSheet(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGreyOutlinedButton(
                        icon: AppIcons.calendar_today,
                        label: '日程を追加',
                        onPressed: () {
                          if (_selectedDate == null || _selectedTimeSlots.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('日付と時間帯を選択してください')),
                            );
                            return;
                          }
                          setState(() {
                            _scheduleEntries.add(_ScheduleEntry(
                              date: _selectedDate!,
                              timeSlots: List.from(_selectedTimeSlots),
                            ));
                            _selectedDate = null;
                            _selectedTimeSlots.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('日程を追加しました')),
                          );
                        },
                        fullWidth: true,
                      ),
                      if (_scheduleEntries.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('追加した日程', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ..._scheduleEntries.asMap().entries.map((e) {
                          final entry = e.value;
                          final index = e.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(AppRadii.sm),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(DateFormat('y/M/d').format(entry.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(entry.timeSlots.join('、'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(AppIcons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => setState(() => _scheduleEntries.removeAt(index)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                    const SizedBox(height: 16),

                    // 説明
                    const Text('説明*', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _descController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '商品の詳細を入力してください',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v == null || v.isEmpty ? '必須です' : null,
                    ),
                    const SizedBox(height: 24),

                    // フッターボタン
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: 下書き保存
                              context.go('/home');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.textPrimary,
                            ),
                            child: const Text('下書きに保存'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    setState(() => _submitting = true);
                                    try {
                                      List<String> urls = [];
                                      try {
                                        urls = await _uploadImages(user.uid);
                                      } catch (e, st) {
                                        if (!mounted) return;
                                        debugPrint('Image upload error: $e\n$st');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '画像のアップロードに失敗しました。'
                                              'Firebase コンソールで Storage が有効か確認してください。',
                                            ),
                                            backgroundColor: Colors.red.shade700,
                                          ),
                                        );
                                        return;
                                      }
                                      final service = Service(
                                        id: '',
                                        ownerId: user.uid,
                                        title: _titleController.text.trim(),
                                        description: _descController.text.trim(),
                                        category: _category,
                                        price: int.parse(_priceController.text.trim()),
                                        duration: _duration,
                                        location: _locationController.text.trim().isEmpty ? '東京都' : _locationController.text.trim(),
                                        onlineAvailable: _online,
                                        offlineAvailable: _offline,
                                        images: urls,
                                        rating: 0,
                                        reviewCount: 0,
                                        createdAt: DateTime.now(),
                                      );
                                      await repo.create(service);
                                      if (mounted) context.go('/home');
                                    } finally {
                                      if (mounted) setState(() => _submitting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(_submitting ? '出品中...' : '出品する'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _imageFiles.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final List<XFile> list;
    if (remaining == 1) {
      final x = await picker.pickImage(source: ImageSource.gallery);
      list = x != null ? [x] : [];
    } else {
      list = await picker.pickMultiImage(limit: remaining);
    }
    if (list.isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (final x in list) {
        if (_imageFiles.length < _maxImages) _imageFiles.add(x);
      }
    });
  }

  Widget _buildImageThumbnail(XFile xFile) {
    final path = xFile.path;
    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
      } catch (_) {}
    }
    return FutureBuilder<Uint8List>(
      future: xFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(color: Colors.grey.shade300, child: const Center(child: CircularProgressIndicator()));
      },
    );
  }

  Future<List<String>> _uploadImages(String userId) async {
    if (_imageFiles.isEmpty) return [];
    final storage = FirebaseStorage.instance;
    final ref = storage.ref().child('services').child(userId);
    final urls = <String>[];
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _imageFiles.length; i++) {
      final xFile = _imageFiles[i];
      final ext = xFile.name.split('.').length > 1 ? xFile.name.split('.').last : 'jpg';
      final fileRef = ref.child('${ts}_$i.$ext');
      final bytes = await xFile.readAsBytes();
      await fileRef.putData(bytes);
      String url = await _getDownloadUrlWithRetry(fileRef);
      urls.add(url);
    }
    return urls;
  }

  Future<String> _getDownloadUrlWithRetry(Reference ref, {int maxAttempts = 3}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await ref.getDownloadURL();
      } catch (_) {
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw StateError('getDownloadURL failed after $maxAttempts attempts');
  }

  Widget _buildTapField({
    required String? value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          value ?? '',
          style: TextStyle(
            color: value != null ? AppColors.textPrimary : null,
          ),
        ),
      ),
    );
  }

  void _showDatePickerBottomSheet(BuildContext context) {
    var picked = _selectedDate ?? DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedDate = picked);
                        Navigator.pop(ctx);
                      },
                      child: const Text('決定'),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: 320,
                      child: CalendarDatePicker(
                        initialDate: picked,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        currentDate: DateTime.now(),
                        onDateChanged: (d) => picked = d,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimeSlotBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.5;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('時間帯を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _timeSlots.length,
                    itemBuilder: (_, i) {
                      final slot = _timeSlots[i];
                      return ListTile(
                        title: Text(slot),
                        onTap: () {
                          setState(() {
                            if (!_selectedTimeSlots.contains(slot)) {
                              _selectedTimeSlots.add(slot);
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildGreyOutlinedButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpacing.listHorizontal),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
