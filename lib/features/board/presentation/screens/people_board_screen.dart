import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

class PeopleBoardScreen extends ConsumerStatefulWidget {
  const PeopleBoardScreen({super.key, this.initialQuery, this.initialCategory});

  final String? initialQuery;
  final String? initialCategory;

  @override
  ConsumerState<PeopleBoardScreen> createState() => _PeopleBoardScreenState();
}

class _PeopleBoardScreenState extends ConsumerState<PeopleBoardScreen> {
  late final TextEditingController _searchController;
  late String _query;
  _AdvancedSearchFilter _filter = const _AdvancedSearchFilter();

  @override
  void initState() {
    super.initState();
    _query = (widget.initialQuery ?? '').trim();
    _searchController = TextEditingController(text: _query);
    final initialCategory = widget.initialCategory?.trim();
    if (initialCategory != null && initialCategory.isNotEmpty) {
      _filter = _AdvancedSearchFilter(category: initialCategory);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.listHorizontal,
                AppSpacing.md,
                AppSpacing.listHorizontal,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBEDF0),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value.trim()),
                        decoration: InputDecoration(
                          hintText: '年齢、身長検索が可能になりました',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB5B8BF),
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: const Icon(
                            AppIcons.search,
                            color: Color(0xFFB5B8BF),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: _openAdvancedSearch,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Center(
                            child: Icon(AppIcons.slider_horizontal_3, size: 24),
                          ),
                          if (_filter.hasAnyFilter)
                            const Positioned(
                              right: -1,
                              top: -1,
                              child: _FilterDot(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('読み込みに失敗しました: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? const [];
                  final cards = docs
                      .map((doc) => _PersonCardData.fromDoc(doc))
                      .where((e) => e.displayName.isNotEmpty)
                      .where((e) {
                        if (query.isEmpty) return true;
                        return e.displayName.toLowerCase().contains(query) ||
                            e.bio.toLowerCase().contains(query) ||
                            e.location.toLowerCase().contains(query);
                      })
                      .where((e) => _filter.matches(e))
                      .toList();

                  cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  if (cards.isEmpty) {
                    return const Center(
                      child: Text(
                        '表示できるユーザーがいません',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.listHorizontal,
                      AppSpacing.xs,
                      AppSpacing.listHorizontal,
                      AppSpacing.md,
                    ),
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final p = cards[index];
                      return _BoardCard(
                        data: p,
                        onTap: () => context.push('/people/${p.userId}'),
                        onMessageTap: () => _openChatWithUser(p.userId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdvancedSearch() async {
    final result = await showModalBottomSheet<_AdvancedSearchFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => _AdvancedSearchSheet(initial: _filter),
    );

    if (result != null) {
      setState(() => _filter = result);
    }
  }

  Future<void> _openChatWithUser(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }
    if (me.uid == otherUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自分自身にはメッセージできません')),
      );
      return;
    }
    try {
      final chatId = await ref.read(chatRepositoryProvider).findOrCreateChat(
            me.uid,
            otherUserId,
          );
      if (!mounted) return;
      context.push('/chats/$chatId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('チャットを開けませんでした: $e')),
      );
    }
  }
}

class _PersonCardData {
  const _PersonCardData({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.hourlyRate,
    required this.photoUrl,
    required this.location,
    required this.createdAt,
    required this.categoryLabel,
    required this.gender,
    required this.availability,
  });

  final String userId;
  final String displayName;
  final String bio;
  final int? hourlyRate;
  final String? photoUrl;
  final String location;
  final DateTime createdAt;
  final String categoryLabel;
  final String gender;
  final String availability;

  factory _PersonCardData.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _PersonCardData(
      userId: doc.id,
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      bio: (data['bio'] as String?)?.trim() ?? '',
      hourlyRate: data['hourlyRate'] is num ? (data['hourlyRate'] as num).toInt() : null,
      photoUrl: (data['photoURL'] as String?)?.trim(),
      location: (data['location'] as String?)?.trim() ?? '未設定',
      createdAt: _readDate(data['createdAt']) ??
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      categoryLabel: (data['category'] as String?)?.trim() ?? '趣味・体験',
      gender: (data['gender'] as String?)?.trim().toLowerCase() ?? '',
      availability: (data['availability'] as String?)?.trim() ?? '',
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}

class _FilterDot extends StatelessWidget {
  const _FilterDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }
}

class _AdvancedSearchSheet extends StatefulWidget {
  const _AdvancedSearchSheet({required this.initial});

  final _AdvancedSearchFilter initial;

  @override
  State<_AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<_AdvancedSearchSheet> {
  late String? _category;
  late String? _gender;
  late int? _minRate;
  late int? _maxRate;
  late bool _onlyWithRate;
  late String _location;
  late String _availability;
  static const _minRateOptions = [
    _RateOption(null, '指定なし'),
    _RateOption(1000, '¥1,000'),
    _RateOption(3000, '¥3,000'),
    _RateOption(5000, '¥5,000'),
    _RateOption(8000, '¥8,000'),
    _RateOption(10000, '¥10,000'),
  ];
  static const _maxRateOptions = [
    _RateOption(null, '指定なし'),
    _RateOption(3000, '¥3,000'),
    _RateOption(5000, '¥5,000'),
    _RateOption(8000, '¥8,000'),
    _RateOption(10000, '¥10,000'),
    _RateOption(15000, '¥15,000'),
  ];
  static const _categoryOptions = [
    _CategoryOption(null, '指定なし'),
    _CategoryOption('トーク・雑談', 'トーク・雑談'),
    _CategoryOption('相談・アドバイス', '相談・アドバイス'),
    _CategoryOption('カフェ・ご飯', 'カフェ・ご飯'),
    _CategoryOption('趣味・遊び', '趣味・遊び'),
    _CategoryOption('お出かけ・同行', 'お出かけ・同行'),
    _CategoryOption('その他', 'その他'),
  ];

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _gender = widget.initial.gender;
    _minRate = widget.initial.minHourlyRate;
    _maxRate = widget.initial.maxHourlyRate;
    _onlyWithRate = widget.initial.onlyWithHourlyRate;
    _location = widget.initial.locationKeyword;
    _availability = widget.initial.availabilityKeyword;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.listHorizontal,
        right: AppSpacing.listHorizontal,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: SizedBox(
                width: 40,
                child: Divider(thickness: 3, color: Color(0xFFD4D7DE)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '高度な検索',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownFlutter<_CategoryOption>(
              hintText: 'カテゴリ',
              items: _categoryOptions,
              initialItem: _categoryOptions.firstWhere(
                (e) => e.value == _category,
                orElse: () => _categoryOptions.first,
              ),
              onChanged: (v) => setState(() => _category = v?.value),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('性別', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ChoiceChip(
                  label: '指定なし',
                  selected: _gender == null,
                  onTap: () => setState(() => _gender = null),
                ),
                _ChoiceChip(
                  label: '女性',
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
                _ChoiceChip(
                  label: '男性',
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('時給', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('最低', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      DropdownFlutter<_RateOption>(
                        hintText: '最低',
                        items: _minRateOptions,
                        initialItem: _minRateOptions.firstWhere(
                          (e) => e.value == _minRate,
                          orElse: () => _minRateOptions.first,
                        ),
                        onChanged: (v) => setState(() => _minRate = v?.value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('最高', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      DropdownFlutter<_RateOption>(
                        hintText: '最高',
                        items: _maxRateOptions,
                        initialItem: _maxRateOptions.firstWhere(
                          (e) => e.value == _maxRate,
                          orElse: () => _maxRateOptions.first,
                        ),
                        onChanged: (v) => setState(() => _maxRate = v?.value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _onlyWithRate,
              title: const Text('時給設定ありのみ'),
              onChanged: (v) => setState(() => _onlyWithRate = v),
            ),
            TextFormField(
              initialValue: _location,
              decoration: const InputDecoration(
                labelText: 'エリア',
                hintText: '例: 東京, 新宿',
              ),
              onChanged: (v) => _location = v.trim(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _availability,
              decoration: const InputDecoration(
                labelText: '稼働可能条件',
                hintText: '例: 平日夜, 土日',
              ),
              onChanged: (v) => _availability = v.trim(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const _AdvancedSearchFilter()),
                    child: const Text('リセット'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _AdvancedSearchFilter(
                          category: _category,
                          gender: _gender,
                          minHourlyRate: _minRate,
                          maxHourlyRate: _maxRate,
                          onlyWithHourlyRate: _onlyWithRate,
                          locationKeyword: _location,
                          availabilityKeyword: _availability,
                        ),
                      );
                    },
                    child: const Text('適用する'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primarySoft,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AdvancedSearchFilter {
  const _AdvancedSearchFilter({
    this.category,
    this.gender,
    this.minHourlyRate,
    this.maxHourlyRate,
    this.onlyWithHourlyRate = false,
    this.locationKeyword = '',
    this.availabilityKeyword = '',
  });

  final String? category;
  final String? gender;
  final int? minHourlyRate;
  final int? maxHourlyRate;
  final bool onlyWithHourlyRate;
  final String locationKeyword;
  final String availabilityKeyword;

  bool get hasAnyFilter =>
      category != null ||
      gender != null ||
      minHourlyRate != null ||
      maxHourlyRate != null ||
      onlyWithHourlyRate ||
      locationKeyword.trim().isNotEmpty ||
      availabilityKeyword.trim().isNotEmpty;

  bool matches(_PersonCardData card) {
    if (category != null && category!.isNotEmpty) {
      final target = category!.trim();
      if (card.categoryLabel.trim() != target) return false;
    }
    final rate = card.hourlyRate;
    if (onlyWithHourlyRate && rate == null) return false;
    if (minHourlyRate != null && (rate == null || rate < minHourlyRate!)) return false;
    if (maxHourlyRate != null && (rate == null || rate > maxHourlyRate!)) return false;
    if (gender != null && card.gender != gender) return false;

    final locationQ = locationKeyword.trim().toLowerCase();
    if (locationQ.isNotEmpty && !card.location.toLowerCase().contains(locationQ)) {
      return false;
    }

    final availabilityQ = availabilityKeyword.trim().toLowerCase();
    if (availabilityQ.isNotEmpty &&
        !card.availability.toLowerCase().contains(availabilityQ)) {
      return false;
    }
    return true;
  }
}

class _RateOption {
  const _RateOption(this.value, this.label);
  final int? value;
  final String label;

  @override
  String toString() => label;
}

class _CategoryOption {
  const _CategoryOption(this.value, this.label);
  final String? value;
  final String label;

  @override
  String toString() => label;
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.data,
    required this.onTap,
    required this.onMessageTap,
  });

  final _PersonCardData data;
  final VoidCallback onTap;
  final VoidCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: const Color(0xFFE7E7EA)),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox(
                    width: 108,
                    height: 132,
                    child: data.photoUrl == null || data.photoUrl!.isEmpty
                        ? Container(
                            color: const Color(0xFFEFF1F5),
                            child: const Icon(AppIcons.person, size: 42, color: Color(0xFF9FA5B1)),
                          )
                        : Image.network(
                            data.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFEFF1F5),
                              child: const Icon(AppIcons.person, size: 42, color: Color(0xFF9FA5B1)),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('🎭 ${data.categoryLabel}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          const Text('📍', style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              data.location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.bio.isEmpty ? '${data.displayName}さんとお話ししませんか？' : data.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 40 / 2, // 20
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF121317),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.hourlyRate == null ? '¥--' : '¥${_formatYen(data.hourlyRate!)}',
                        style: const TextStyle(fontSize: 44 / 2, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.bio.isEmpty
                  ? 'はじめまして。お気軽にメッセージしてください。'
                  : data.bio,
              style: const TextStyle(
                fontSize: 18 / 1.9,
                height: 1.45,
                color: Color(0xFF14151A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEAEBEF)),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE7EBF1),
                  backgroundImage: data.photoUrl == null || data.photoUrl!.isEmpty
                      ? null
                      : NetworkImage(data.photoUrl!),
                  child: data.photoUrl == null || data.photoUrl!.isEmpty
                      ? const Icon(AppIcons.person, size: 16, color: Color(0xFF7F8795))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _metaLine(data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8C9098), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onMessageTap,
                    icon: const Icon(AppIcons.send, size: 16),
                    label: const Text(
                      'メッセージ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0,
                      textStyle: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _metaLine(_PersonCardData data) {
    final age = data.createdAt.year > 2000 ? '${DateTime.now().year - data.createdAt.year}歳' : '';
    if (age.isEmpty) return 'プロフィールを見る';
    return '$age / メンバー';
  }
}

String _formatYen(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    b.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      b.write(',');
    }
  }
  return b.toString();
}
