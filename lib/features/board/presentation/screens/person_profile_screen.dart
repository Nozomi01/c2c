import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../../core/ui/user_favorite_button.dart';

class PersonProfileScreen extends ConsumerStatefulWidget {
  const PersonProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PersonProfileScreen> createState() =>
      _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('ユーザー情報が見つかりません'));
          }

          final displayName = (data['displayName'] as String?)?.trim() ?? 'ユーザー';
          final bio = (data['bio'] as String?)?.trim() ?? '';
          final hourlyRate =
              data['hourlyRate'] is num ? (data['hourlyRate'] as num).toInt() : null;
          final photoUrl = (data['photoURL'] as String?)?.trim();
          final location = (data['location'] as String?)?.trim() ?? '未設定';
          final availability = (data['availability'] as String?)?.trim() ?? '未設定';
          final skillsText = (data['skills'] as String?)?.trim() ?? '';
          final skills = skillsText
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .take(3)
              .toList();
          final ratingRaw = data['rating'];
          final reviewCountRaw = data['reviewCount'];
          final rating = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
          final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    _HeroSection(
                      displayName: displayName,
                      rating: rating,
                      reviewCount: reviewCount,
                      location: location,
                      imageUrl: photoUrl,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadii.xxxl),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.listHorizontal,
                          AppSpacing.md,
                          AppSpacing.listHorizontal,
                          120,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      for (final s in skills)
                                        _TagChip(label: s),
                                      if (skills.isEmpty) const _TagChip(label: '自己紹介参照'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '時給',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      hourlyRate == null ? '未設定' : '¥${_formatYen(hourlyRate)}',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _ProfileTabbedSection(
                              userId: widget.userId,
                              reviewCount: reviewCount,
                              rating: rating,
                              displayName: displayName,
                              bio: bio,
                              availability: availability,
                              location: location,
                              skills: skills,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                left: AppSpacing.listHorizontal,
                right: AppSpacing.listHorizontal,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: AppIcons.chevron_left,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      UserFavoriteButton(
                        targetUserId: widget.userId,
                        compact: false,
                        backgroundAlpha: 0.45,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _CircleIconButton(
                        icon: AppIcons.share_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.listHorizontal,
                right: AppSpacing.listHorizontal,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 62,
                    child: ElevatedButton.icon(
                      onPressed: () => _openContractRequestSheet(
                        context: context,
                        sellerDisplayName: displayName,
                        sellerHourlyRate: hourlyRate,
                        availability: availability,
                        location: location,
                      ),
                      icon: const Icon(AppIcons.calendar_today, color: Colors.white),
                      label: const Text(
                        '予約リクエストへ進む',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openContractRequestSheet({
    required BuildContext context,
    required String sellerDisplayName,
    required int? sellerHourlyRate,
    required String availability,
    required String location,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }
    if (me.uid == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自分自身には依頼できません')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => _ProfileContractRequestSheet(
        sellerId: widget.userId,
        sellerDisplayName: sellerDisplayName,
        sellerHourlyRate: sellerHourlyRate,
        availability: availability,
        location: location,
      ),
    );
  }
}

class _ProfileContractRequestSheet extends StatefulWidget {
  const _ProfileContractRequestSheet({
    required this.sellerId,
    required this.sellerDisplayName,
    required this.sellerHourlyRate,
    required this.availability,
    required this.location,
  });

  final String sellerId;
  final String sellerDisplayName;
  final int? sellerHourlyRate;
  final String availability;
  final String location;

  @override
  State<_ProfileContractRequestSheet> createState() =>
      _ProfileContractRequestSheetState();
}

class _ProfileContractRequestSheetState
    extends State<_ProfileContractRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _detailController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _timelineLabel {
    if (_selectedDate == null || _selectedTime == null) {
      return '希望日時を選択（任意）';
    }
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime:
          _selectedTime ?? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final now = Timestamp.now();
      String? timeline;
      if (_selectedDate != null && _selectedTime != null) {
        final dt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        timeline = DateFormat('yyyy/MM/dd HH:mm').format(dt);
      }
      final docRef = await FirebaseFirestore.instance.collection('serviceRequests').add({
        'requestType': 'profileContract',
        'serviceId': null,
        'serviceTitle': 'プロフィール契約',
        'sellerId': widget.sellerId,
        'sellerName': widget.sellerDisplayName,
        'buyerId': me.uid,
        'buyerName': me.displayName ?? me.email ?? '依頼者',
        'detail': _detailController.text.trim(),
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        'timeline': timeline,
        'offeredHourlyRate': widget.sellerHourlyRate,
        'availabilitySnapshot': widget.availability,
        'locationSnapshot': widget.location,
        'status': 'requested',
        'createdAt': now,
        'updatedAt': now,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('契約依頼を送信しました')),
      );
      context.push('/seller/requests/${docRef.id}');
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.listHorizontal,
        right: AppSpacing.listHorizontal,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
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
              Text(
                '${widget.sellerDisplayName}さんに依頼',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.sellerHourlyRate == null
                    ? '時給: 未設定'
                    : '時給: ¥${_formatYen(widget.sellerHourlyRate)} / 時間',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '対応可能: ${widget.availability.isEmpty ? '未設定' : widget.availability}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _detailController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '依頼内容',
                  hintText: 'お願いしたい内容を具体的に入力してください',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '依頼内容を入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'メッセージ（任意）',
                  hintText: '補足事項があれば入力',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDateTime(context),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.calendar_today,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _timelineLabel,
                          style: TextStyle(
                            color: _selectedDate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? '送信中...' : 'この内容で依頼する'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabbedSection extends StatefulWidget {
  const _ProfileTabbedSection({
    required this.userId,
    required this.reviewCount,
    required this.rating,
    required this.displayName,
    required this.bio,
    required this.availability,
    required this.location,
    required this.skills,
  });

  final String userId;
  final int reviewCount;
  final double rating;
  final String displayName;
  final String bio;
  final String availability;
  final String location;
  final List<String> skills;

  @override
  State<_ProfileTabbedSection> createState() => _ProfileTabbedSectionState();
}

class _ProfileTabbedSectionState extends State<_ProfileTabbedSection> {
  int _tabIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _moveToPage(int index) {
    if (_tabIndex != index) {
      setState(() => _tabIndex = index);
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TabButton(
              label: '自己紹介',
              selected: _tabIndex == 0,
              onTap: () => _moveToPage(0),
            ),
            const SizedBox(width: AppSpacing.xl),
            _TabButton(
              label: 'レビュー (${widget.reviewCount})',
              selected: _tabIndex == 1,
              onTap: () => _moveToPage(1),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: Color(0xFFE5E5EA)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 560,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_tabIndex != index) {
                setState(() => _tabIndex = index);
              }
            },
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _IntroTab(
                  bio: widget.bio,
                  availability: widget.availability,
                  location: widget.location,
                  sceneTags: widget.skills,
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _ReviewTab(
                  userId: widget.userId,
                  rating: widget.rating,
                  reviewCount: widget.reviewCount,
                  displayName: widget.displayName,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatYen(int? value) {
  if (value == null) return '0';
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idxFromEnd = s.length - i;
    b.write(s[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) b.write(',');
  }
  return b.toString();
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.displayName,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.imageUrl,
  });

  final String displayName;
  final double rating;
  final int reviewCount;
  final String location;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xAA000000), Color(0x22000000), Color(0x11000000)],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.listHorizontal,
            right: AppSpacing.listHorizontal,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xFF5B7BFF),
                      child: Icon(AppIcons.check, color: Colors.white, size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(AppIcons.star, color: AppColors.primary, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} ($reviewCount)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(AppIcons.location_on, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF8D8D8D),
      child: const Center(
        child: Icon(AppIcons.person, color: Colors.white70, size: 78),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66FFFFFF),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : const Color(0xFF9BA0AE),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 2.2,
            color: selected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _IntroTab extends StatelessWidget {
  const _IntroTab({
    required this.bio,
    required this.availability,
    required this.location,
    required this.sceneTags,
  });

  final String bio;
  final String availability;
  final String location;
  final List<String> sceneTags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'プロフィール',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          bio.isEmpty ? '自己紹介はまだ登録されていません。' : bio,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text(
          '対応可能なシーン',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tag in sceneTags) _SceneChip(label: tag),
            if (sceneTags.isEmpty) const _SceneChip(label: '相談'),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F6),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(AppIcons.schedule, color: Color(0xFF8C90A1)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '稼働可能: $availability',
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(AppIcons.location_on, color: Color(0xFF8C90A1)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '主な活動エリア: $location',
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SceneChip extends StatelessWidget {
  const _SceneChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1FF),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF4D5DDF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewTab extends StatelessWidget {
  const _ReviewTab({
    required this.userId,
    required this.rating,
    required this.reviewCount,
    required this.displayName,
  });

  final String userId;
  final double rating;
  final int reviewCount;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final sellerReviewsStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('sellerId', isEqualTo: userId)
        .snapshots();
    final buyerReviewsStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('buyerId', isEqualTo: userId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sellerReviewsStream,
      builder: (context, sellerSnap) {
        if (sellerSnap.hasError) {
          return _ReviewLoadError(message: sellerSnap.error.toString());
        }
        if (sellerSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: buyerReviewsStream,
          builder: (context, buyerSnap) {
            if (buyerSnap.hasError) {
              return _ReviewLoadError(message: buyerSnap.error.toString());
            }
            if (buyerSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final reviews = <_ReviewItem>[
              ..._extractSellerSideReviews(sellerSnap.data?.docs ?? const []),
              ..._extractBuyerSideReviews(buyerSnap.data?.docs ?? const []),
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final effectiveCount = reviews.isEmpty ? reviewCount : reviews.length;
            final effectiveRating = reviews.isEmpty
                ? rating
                : reviews.map((e) => e.rating).reduce((a, b) => a + b) /
                    reviews.length;
            final distribution = _ratingDistribution(reviews);

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              effectiveRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 34, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: List.generate(5, (i) {
                                final stars = 5 - i;
                                final ratio = reviews.isEmpty
                                    ? 0.0
                                    : (distribution[stars] ?? 0) / reviews.length;
                                return _RatingBar(
                                  label: '$stars',
                                  value: ratio.clamp(0, 1).toDouble(),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(AppIcons.star,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${effectiveRating.toStringAsFixed(1)} ($effectiveCount)',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (reviews.isEmpty)
                  Text(
                    'レビューはまだありません',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...reviews.map(
                    (r) => _ReviewCard(
                      name: r.reviewerLabel,
                      displayName: displayName,
                      rating: r.rating,
                      comment: r.comment,
                      createdAt: r.createdAt,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

List<_ReviewItem> _extractSellerSideReviews(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final out = <_ReviewItem>[];
  for (final doc in docs) {
    final d = doc.data();
    final rawRating = d['rating'];
    if (rawRating is! num || rawRating <= 0) continue;
    final rawComment = d['reviewComment'];
    final comment = rawComment is String ? rawComment.trim() : '';
    final createdAt = _readDate(d['reviewedAt']) ??
        _readDate(d['updatedAt']) ??
        _readDate(d['createdAt']) ??
        DateTime.now();
    out.add(
      _ReviewItem(
        rating: rawRating.toDouble(),
        comment: comment,
        createdAt: createdAt,
        reviewerLabel: '利用者',
      ),
    );
  }
  return out;
}

List<_ReviewItem> _extractBuyerSideReviews(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final out = <_ReviewItem>[];
  for (final doc in docs) {
    final d = doc.data();
    final rawRating = d['buyerRating'];
    if (rawRating is! num || rawRating <= 0) continue;
    final rawComment = d['buyerReviewComment'];
    final comment = rawComment is String ? rawComment.trim() : '';
    final createdAt = _readDate(d['buyerReviewedAt']) ??
        _readDate(d['updatedAt']) ??
        _readDate(d['createdAt']) ??
        DateTime.now();
    out.add(
      _ReviewItem(
        rating: rawRating.toDouble(),
        comment: comment,
        createdAt: createdAt,
        reviewerLabel: '出品者',
      ),
    );
  }
  return out;
}

DateTime? _readDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}

Map<int, int> _ratingDistribution(List<_ReviewItem> reviews) {
  final map = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (final r in reviews) {
    final key = r.rating.round().clamp(1, 5);
    map[key] = (map[key] ?? 0) + 1;
  }
  return map;
}

class _ReviewItem {
  const _ReviewItem({
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.reviewerLabel,
  });

  final double rating;
  final String comment;
  final DateTime createdAt;
  final String reviewerLabel;
}

class _ReviewLoadError extends StatelessWidget {
  const _ReviewLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'レビューを読み込めませんでした。\n$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 12, child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E3E7),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.displayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String name;
  final String displayName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 20, backgroundColor: Color(0xFFE4E4E7), child: Text('ユ')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      DateFormat('yyyy-MM-dd').format(createdAt),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.round()
                        ? AppIcons.star
                        : AppIcons.star_border,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.isEmpty
                ? '$displayName さんへの評価が投稿されました。'
                : comment,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
        ],
      ),
    );
  }
}
