import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
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
  final List<String> _imageUrls = [];
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
    _CategoryItem('トーク・雑談', Icons.chat_bubble_outline),
    _CategoryItem('相談・アドバイス', Icons.lightbulb_outline),
    _CategoryItem('カフェ・ご飯', Icons.restaurant_outlined),
    _CategoryItem('趣味・遊び', Icons.sports_esports_outlined),
    _CategoryItem('お出かけ・同行', Icons.person_outline),
    _CategoryItem('その他', Icons.star_border),
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('新規出品'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('ログインが必要です'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品画像
                    const Text('商品画像', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        // TODO: 画像アップロード
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, size: 32, color: Colors.grey.shade600),
                            const SizedBox(height: 8),
                            Text('追加', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('最大10枚まで追加できます', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primarySoft : Colors.white,
                              borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                              icon: Icons.calendar_today,
                              onTap: () => _showDatePickerBottomSheet(context),
                            ),
                            const SizedBox(height: 12),
                            const Text('時間帯', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            _buildTapField(
                              value: _selectedTimeSlots.isEmpty ? null : _selectedTimeSlots.first,
                              hint: '時間帯を選択',
                              icon: Icons.access_time,
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
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () => setState(() => _selectedTimeSlots.remove(slot)),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildGreyOutlinedButton(
                              icon: Icons.add,
                              label: '時間帯を追加',
                              onPressed: () => _showTimeSlotBottomSheet(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGreyOutlinedButton(
                        icon: Icons.calendar_today,
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
                                      borderRadius: BorderRadius.circular(10),
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
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
                              Navigator.of(context).pop();
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
                                        images: _imageUrls,
                                        rating: 0,
                                        reviewCount: 0,
                                        createdAt: DateTime.now(),
                                      );
                                      await repo.create(service);
                                      if (mounted) Navigator.of(context).pop();
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

  Widget _buildTapField({
    required String? value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('時間帯を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._timeSlots.map((slot) => ListTile(
                  title: Text(slot),
                  onTap: () {
                    setState(() {
                      if (!_selectedTimeSlots.contains(slot)) {
                        _selectedTimeSlots.add(slot);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
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
