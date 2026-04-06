import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../../core/ui/user_favorite_button.dart';

/// Shared card chrome for home (shadow must sit outside [ClipRRect] to render correctly).
const List<BoxShadow> _kHomeCardShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
  BoxShadow(
    color: Color(0x08000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];
const Color _kHomeCardBorder = Color(0xFFE8EAEF);
const double _kHomeCardRadius = 20;
const double _kHomeHeroCardRadius = 24;

/// Same labels as quick chips (indices 1…8) and category listings.
const _kHomePopularCategoryNames = <String>[
  'カフェ・お茶',
  '悩み相談',
  'ランチ・食事',
  'お散歩・街歩き',
  'お買い物',
  '趣味・エンタメ',
  '写真・SNS',
  'オンライン',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Quick filter: 0 = すべて, 1…8 = category chips (same order as HTML).
  int _selectedQuickChip = 0;

  void _openListings([String? categoryName]) {
    if (categoryName == null || categoryName.isEmpty) {
      context.push('/listings');
    } else {
      context.push('/listings/category?name=${Uri.encodeComponent(categoryName)}');
    }
  }

  void _openFilter() => _openListings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _SearchBar()),
                            const SizedBox(width: 12),
                            _BlackFilterButton(onPressed: _openFilter),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _HomeQuickChips(
                        selectedIndex: _selectedQuickChip,
                        onFilterTap: _openFilter,
                        onSelect: (index) {
                          setState(() => _selectedQuickChip = index);
                          const cats = [
                            '',
                            'カフェ・お茶',
                            '悩み相談',
                            'ランチ・食事',
                            'お散歩・街歩き',
                            'お買い物',
                            '趣味・エンタメ',
                            '写真・SNS',
                            'オンライン',
                          ];
                          if (index == 0) {
                            _openListings();
                          } else {
                            _openListings(cats[index]);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: _PopularUsersByCategoryBlock(
                onSeeAllCategory: _openListings,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _CategorySectionHeader(
                onTap: () => _openListings(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _CategoryShortcutRow(
                onCategoryTap: _openListings,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _PromoBannerStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _WeeklyPickupCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(child: _BulletinPreviewSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: _PopularUsersGlobalSection(
                onSeeAll: () => _openListings(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _FeaturedNewCastsSection(
                onSeeAll: () => _openListings(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: 'カフェ・お茶におすすめ',
                categoryName: 'カフェ・お茶',
                emptyInCategoryMessage: 'カフェ・お茶のユーザーがまだいません',
                onSeeAllCategory: () => _openListings('カフェ・お茶'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: '悩み相談が特技',
                categoryName: '悩み相談',
                emptyInCategoryMessage: '悩み相談のユーザーがまだいません',
                onSeeAllCategory: () => _openListings('悩み相談'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: 'ランチ同行におすすめ',
                categoryName: 'ランチ・食事',
                emptyInCategoryMessage: 'ランチ・食事のユーザーがまだいません',
                onSeeAllCategory: () => _openListings('ランチ・食事'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: 'お散歩・街歩きにおすすめ',
                categoryName: 'お散歩・街歩き',
                emptyInCategoryMessage: 'お散歩・街歩きのユーザーがまだいません',
                onSeeAllCategory: () => _openListings('お散歩・街歩き'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: 'お買い物同行におすすめ',
                categoryName: 'お買い物',
                emptyInCategoryMessage: 'お買い物のユーザーがまだいません',
                onSeeAllCategory: () => _openListings('お買い物'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: '趣味・エンタメを楽しみたい',
                categoryName: '趣味・エンタメ',
                emptyInCategoryMessage: '趣味・エンタメのユーザーがまだいません',
                onSeeAllCategory: () => _openListings('趣味・エンタメ'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: '写真・SNS・他撮りお任せ',
                categoryName: '写真・SNS',
                emptyInCategoryMessage: '写真・SNSのユーザーがまだいません',
                onSeeAllCategory: () => _openListings('写真・SNS'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _HomeCategoryFeaturedSection(
                sectionTitle: 'オンラインで今すぐ話せる',
                categoryName: 'オンライン',
                emptyInCategoryMessage: 'オンラインのユーザーがまだいません',
                onSeeAllCategory: () => _openListings('オンライン'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 32 + AppSpacing.bottomForFloatingShell(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlackFilterButton extends StatelessWidget {
  const _BlackFilterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Center(
            child: Icon(
              AppIcons.slider_horizontal_3,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToSearch() {
    final query = _controller.text.trim();
    final uri = query.isEmpty
        ? '/listings'
        : '/listings?q=${Uri.encodeComponent(query)}';
    context.push(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kHomeCardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: (_) => _goToSearch(),
          decoration: InputDecoration(
            hintText: 'キーワードやエリアで検索',
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
            prefixIcon: Icon(
              AppIcons.search,
              size: 18,
              color: AppColors.textSecondary.withValues(alpha: 0.55),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            isDense: true,
          ),
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }
}

class _HomeQuickChips extends StatelessWidget {
  const _HomeQuickChips({
    required this.selectedIndex,
    required this.onFilterTap,
    required this.onSelect,
  });

  final int selectedIndex;
  final VoidCallback onFilterTap;
  final void Function(int index) onSelect;

  static const _emojiChips = <String>[
    '☕ カフェ・お茶',
    '💬 悩み相談',
    '🍽️ ランチ・食事',
    '🚶 お散歩・街歩き',
    '🛍️ お買い物',
    '🎨 趣味・エンタメ',
    '📷 写真・SNS',
    '💻 オンライン',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.listHorizontal, 0, AppSpacing.listHorizontal, 0),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _FilterIconChip(onTap: onFilterTap),
          ),
          _TextChip(
            label: 'すべて',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 10),
          for (var i = 0; i < _emojiChips.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _TextChip(
              label: _emojiChips[i],
              selected: selectedIndex == i + 1,
              onTap: () => onSelect(i + 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterIconChip extends StatelessWidget {
  const _FilterIconChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.home_chip_filter,
            size: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF111827) : Colors.white;
    final fg = selected ? Colors.white : const Color(0xFF374151);
    final border = selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 2 : 0,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: selected ? 0 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                AppIcons.home_category_header,
                size: 15,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              const Text(
                'カテゴリから探す',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryShortcutRow extends StatelessWidget {
  const _CategoryShortcutRow({required this.onCategoryTap});

  final void Function(String categoryName) onCategoryTap;

  static const _items = <_CategoryShortcut>[
    _CategoryShortcut(
      label: 'カフェ',
      icon: AppIcons.home_row_cafe,
      categoryName: 'カフェ・お茶',
      iconColor: Color(0xFFE65100),
      bg: Color(0xFFFFF3E0),
    ),
    _CategoryShortcut(
      label: '悩み相談',
      icon: AppIcons.home_row_consult,
      categoryName: '悩み相談',
      iconColor: Color(0xFF1565C0),
      bg: Color(0xFFE3F2FD),
    ),
    _CategoryShortcut(
      label: '食事',
      icon: AppIcons.home_row_meal,
      categoryName: 'ランチ・食事',
      iconColor: Color(0xFFC62828),
      bg: Color(0xFFFFEBEE),
    ),
    _CategoryShortcut(
      label: 'お散歩',
      icon: AppIcons.home_row_stroll,
      categoryName: 'お散歩・街歩き',
      iconColor: Color(0xFF2E7D32),
      bg: Color(0xFFE8F5E9),
    ),
    _CategoryShortcut(
      label: 'お買い物',
      icon: AppIcons.home_row_shop,
      categoryName: 'お買い物',
      iconColor: Color(0xFF6A1B9A),
      bg: Color(0xFFF3E5F5),
    ),
    _CategoryShortcut(
      label: 'エンタメ',
      icon: AppIcons.home_row_hobby_entertainment,
      categoryName: '趣味・エンタメ',
      iconColor: Color(0xFFD97706),
      bg: Color(0xFFFEFCE8),
    ),
    _CategoryShortcut(
      label: '写真・SNS',
      icon: AppIcons.home_row_photo_sns,
      categoryName: '写真・SNS',
      iconColor: Color(0xFFEC4899),
      bg: Color(0xFFFDF2F8),
    ),
    _CategoryShortcut(
      label: 'オンライン',
      icon: AppIcons.home_row_online,
      categoryName: 'オンライン',
      iconColor: Color(0xFF283593),
      bg: Color(0xFFE8EAF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = _items[index];
          return InkWell(
            onTap: () => onCategoryTap(item.categoryName),
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: item.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.icon,
                      size: 28,
                      color: item.iconColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryShortcut {
  const _CategoryShortcut({
    required this.label,
    required this.icon,
    required this.categoryName,
    required this.iconColor,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final String categoryName;
  final Color iconColor;
  final Color bg;
}

Widget _homePromoPill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _PromoBannerStrip extends StatelessWidget {
  const _PromoBannerStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
        children: [
          _GradientPromoCard(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
            ),
            watermarkIcon: AppIcons.home_promo_gift,
            watermarkAlignment: Alignment.bottomRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _homePromoPill('期間限定'),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                    children: const [
                      TextSpan(text: '初回利用 '),
                      TextSpan(
                        text: '1,000円OFF!',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _GradientPromoCard(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
            ),
            watermarkIcon: AppIcons.home_promo_bullhorn,
            watermarkAlignment: Alignment.topRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _homePromoPill('キャスト募集'),
                const SizedBox(height: 10),
                const Text(
                  '新規キャストデビュー応援',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
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

class _GradientPromoCard extends StatelessWidget {
  const _GradientPromoCard({
    required this.gradient,
    required this.watermarkIcon,
    required this.watermarkAlignment,
    required this.child,
  });

  final Gradient gradient;
  final IconData watermarkIcon;
  final Alignment watermarkAlignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(_kHomeCardRadius);
    return SizedBox(
      width: 310,
      child: AspectRatio(
        aspectRatio: 21 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            boxShadow: _kHomeCardShadow,
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Container(decoration: BoxDecoration(gradient: gradient)),
                if (watermarkAlignment == Alignment.topRight)
                  Positioned(
                    right: -8,
                    top: -16,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        watermarkIcon,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: -8,
                    bottom: -12,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        watermarkIcon,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyPickupCard extends StatelessWidget {
  const _WeeklyPickupCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(40).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final users = snapshot.data!.docs
            .map(_NewUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();
        users.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        if (users.isEmpty) return const SizedBox.shrink();
        final user = users.first;
        final rate = user.hourlyRate ?? 5000;
        final loc = user.location.isEmpty ? 'エリア未設定' : user.location;

        final heroR = BorderRadius.circular(_kHomeHeroCardRadius);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: heroR,
              boxShadow: _kHomeCardShadow,
            ),
            child: ClipRRect(
              borderRadius: heroR,
              child: Material(
                color: const Color(0xFFE8EAED),
                child: InkWell(
                  onTap: () => context.push('/people/${user.userId}'),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (user.photoUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: user.photoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: const Color(0xFFD1D5DB)),
                          )
                        else
                          Container(color: const Color(0xFFD1D5DB)),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.05),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0, 0.35, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          top: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.star, size: 11, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    const Text(
                                      '今週のピックアップ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          top: 20,
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: UserFavoriteButton(
                                targetUserId: user.userId,
                                compact: false,
                                backgroundAlpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      shadows: [
                                        Shadow(blurRadius: 8, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                  if (user.isVerified) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      AppIcons.verified,
                                      size: 20,
                                      color: const Color(0xFF60A5FA),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.place_outlined,
                                    size: 14,
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      loc,
                                      style: const TextStyle(
                                        color: Color(0xFFE5E7EB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(blurRadius: 6, color: Colors.black54),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        onTap: () => context.push('/people/${user.userId}'),
                                        borderRadius: BorderRadius.circular(16),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          child: Center(
                                            child: Text(
                                              'プロフィールを見る',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '¥${_formatYenThousands(rate)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              '/h',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatYenThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _formatRelativeTimeJa(DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inMinutes < 60) return '${d.inMinutes}分前';
  if (d.inHours < 24) return '${d.inHours}時間前';
  return '${d.inDays}日前';
}

class _BulletinPreviewSection extends StatelessWidget {
  const _BulletinPreviewSection();

  static const _listHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.78).clamp(260.0, 340.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB).withValues(alpha: 0.55),
        border: const Border(
          top: BorderSide(color: Color(0xFFF3F4F6)),
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
            child: Row(
              children: [
                const Icon(
                  AppIcons.bulletin_section_header,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'みんなの募集・つぶやき',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/board'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'すべて見る',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        AppIcons.chevron_right,
                        size: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _listHeight,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('boardPosts')
                  .orderBy('createdAt', descending: true)
                  .limit(12)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      '投稿を読み込めませんでした',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'まだ投稿がありません',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  );
                }
                final n = docs.length > 6 ? 6 : docs.length;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
                  itemCount: n,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final text = (d['text'] as String?) ?? '';
                    final name = (d['displayName'] as String?) ?? '';
                    final photo = (d['photoURL'] as String?) ?? '';
                    final verifiedRaw = d['isVerified'] ?? d['verified'];
                    final verified = verifiedRaw == true;
                    final created = d['createdAt'];
                    DateTime? at;
                    if (created is Timestamp) at = created.toDate();
                    if (created is DateTime) at = created;
                    final timeStr = at != null ? _formatRelativeTimeJa(at) : '';

                    final br = BorderRadius.circular(_kHomeCardRadius);
                    return SizedBox(
                      width: cardW,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: br,
                          boxShadow: _kHomeCardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: br,
                          child: Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: br,
                              side: const BorderSide(color: _kHomeCardBorder),
                            ),
                            child: InkWell(
                              onTap: () => context.push('/board'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipOval(
                                          child: photo.isEmpty
                                              ? Container(
                                                  width: 36,
                                                  height: 36,
                                                  color: const Color(0xFFF3F4F6),
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    AppIcons.person,
                                                    size: 18,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: photo,
                                                  width: 36,
                                                  height: 36,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name.isEmpty ? 'ユーザー' : name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (verified) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  AppIcons.verified,
                                                  size: 16,
                                                  color: Color(0xFF1DA1F2),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: Text(
                                        text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-rated users across all categories (「人気のユーザー」).
class _PopularUsersGlobalSection extends StatelessWidget {
  const _PopularUsersGlobalSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  static const double _listHeight = 316;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: _listHeight + 48,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final items = (snapshot.data?.docs ?? const [])
            .map(_PopularUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();

        items.sort((a, b) => b.rating.compareTo(a.rating));
        final popular = items.take(12).toList();

        if (popular.isEmpty) {
          return const SizedBox.shrink();
        }

        return _PopularUsersCategoryRow(
          sectionTitle: '人気のユーザー',
          onSeeAll: onSeeAll,
          users: popular,
        );
      },
    );
  }
}

/// Newest users (「注目の新規キャスト」) — same card row as [ _PopularUsersGlobalSection ].
class _FeaturedNewCastsSection extends StatelessWidget {
  const _FeaturedNewCastsSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  static const double _listHeight = 316;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: _listHeight + 48,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final items = (snapshot.data?.docs ?? const [])
            .map(_PopularUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();

        items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        final newest = items.take(12).toList();

        if (newest.isEmpty) {
          return const SizedBox.shrink();
        }

        return _PopularUsersCategoryRow(
          sectionTitle: '注目の新規キャスト',
          onSeeAll: onSeeAll,
          users: newest,
          leadingIcon: AppIcons.home_featured_new_cast_row_header,
          leadingIconColor: const Color(0xFFF59E0B),
        );
      },
    );
  }
}

/// Top-rated users whose Firestore `category` matches [categoryName] (same row UI as 「人気のユーザー」).
class _HomeCategoryFeaturedSection extends StatelessWidget {
  const _HomeCategoryFeaturedSection({
    required this.sectionTitle,
    required this.categoryName,
    required this.emptyInCategoryMessage,
    required this.onSeeAllCategory,
  });

  final String sectionTitle;
  final String categoryName;
  final String emptyInCategoryMessage;
  final VoidCallback onSeeAllCategory;

  static const double _listHeight = 316;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: _listHeight + 48,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return _PopularUsersCategoryRow(
            sectionTitle: sectionTitle,
            onSeeAll: onSeeAllCategory,
            users: const [],
            emptyMessage: 'ユーザー情報を読み込めませんでした',
            leadingIcon: AppIcons.homeRecommendedRowIconForCategory(categoryName),
            leadingIconColor:
                AppIcons.homeRecommendedRowIconTintForCategory(categoryName),
          );
        }

        final all = (snapshot.data?.docs ?? const [])
            .map(_PopularUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();

        final inCategory =
            all.where((u) => u.categoryLabel.trim() == categoryName).toList();
        inCategory.sort((a, b) => b.rating.compareTo(a.rating));
        final popular = inCategory.take(12).toList();

        if (popular.isEmpty) {
          return _PopularUsersCategoryRow(
            sectionTitle: sectionTitle,
            onSeeAll: onSeeAllCategory,
            users: const [],
            emptyMessage: all.isEmpty ? '表示できるユーザーがいません' : emptyInCategoryMessage,
            leadingIcon: AppIcons.homeRecommendedRowIconForCategory(categoryName),
            leadingIconColor:
                AppIcons.homeRecommendedRowIconTintForCategory(categoryName),
          );
        }

        return _PopularUsersCategoryRow(
          sectionTitle: sectionTitle,
          onSeeAll: onSeeAllCategory,
          users: popular,
          leadingIcon: AppIcons.homeRecommendedRowIconForCategory(categoryName),
          leadingIconColor:
              AppIcons.homeRecommendedRowIconTintForCategory(categoryName),
        );
      },
    );
  }
}

class _PopularUsersByCategoryBlock extends StatelessWidget {
  const _PopularUsersByCategoryBlock({required this.onSeeAllCategory});

  final void Function(String categoryName) onSeeAllCategory;

  static const double _listHeight = 316;

  static List<_PopularUserItem> _popularForCategory(
    List<_PopularUserItem> all,
    String categoryName,
  ) {
    final filtered = all.where((u) => u.categoryLabel == categoryName).toList();
    filtered.sort((a, b) => b.rating.compareTo(a.rating));
    return filtered.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: _listHeight + 48,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final items = (snapshot.data?.docs ?? const [])
            .map(_PopularUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();

        final rows = <Widget>[];
        for (final cat in _kHomePopularCategoryNames) {
          final popular = _popularForCategory(items, cat);
          if (popular.isEmpty) continue;
          rows.add(
            _PopularUsersCategoryRow(
              sectionTitle: cat,
              onSeeAll: () => onSeeAllCategory(cat),
              users: popular,
              leadingIcon: AppIcons.homeRecommendedRowIconForCategory(cat),
              leadingIconColor:
                  AppIcons.homeRecommendedRowIconTintForCategory(cat),
            ),
          );
        }

        if (rows.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1) const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }
}

class _PopularUsersCategoryRow extends StatelessWidget {
  const _PopularUsersCategoryRow({
    required this.sectionTitle,
    required this.onSeeAll,
    required this.users,
    this.emptyMessage,
    this.leadingIcon,
    this.leadingIconColor,
  });

  final String sectionTitle;
  final VoidCallback onSeeAll;
  final List<_PopularUserItem> users;
  /// When [users] is empty, show this instead of an empty strip (optional).
  final String? emptyMessage;
  /// Defaults to [AppIcons.home_popular_row_header] (flame) for 「人気のユーザー」.
  final IconData? leadingIcon;
  /// Defaults to warm red when [leadingIcon] is null.
  final Color? leadingIconColor;

  static const double _cardWidth = 200;
  static const double _listHeight = 316;

  @override
  Widget build(BuildContext context) {
    final listChild = users.isEmpty && emptyMessage != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
              child: Text(
                emptyMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return SizedBox(
                width: _cardWidth,
                child: _PopularUserCard(
                  user: users[index],
                  badgeVariant: index.isEven
                      ? _PopularBadgeVariant.availableToday
                      : _PopularBadgeVariant.viewers,
                ),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
          child: Row(
            children: [
              Icon(
                leadingIcon ?? AppIcons.home_popular_row_header,
                size: 22,
                color: leadingIconColor ?? const Color(0xFFE53935),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(AppRadii.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Text(
                    'すべて見る',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _listHeight,
          child: listChild,
        ),
      ],
    );
  }
}

enum _PopularBadgeVariant { availableToday, viewers }

class _PopularUserCard extends StatelessWidget {
  const _PopularUserCard({
    required this.user,
    required this.badgeVariant,
  });

  final _PopularUserItem user;
  final _PopularBadgeVariant badgeVariant;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,###');
    final price = user.hourlyRate ?? 5000;
    final loc = user.location.isEmpty ? '東京都' : user.location;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/people/${user.userId}'),
        borderRadius: BorderRadius.circular(_kHomeCardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            border: Border.all(color: _kHomeCardBorder),
            boxShadow: _kHomeCardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kHomeCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 198,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: user.photoUrl.isEmpty
                            ? Container(
                                color: const Color(0xFFE8EEF4),
                                alignment: Alignment.center,
                                child: Icon(
                                  AppIcons.person,
                                  size: 72,
                                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: user.photoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFE8EEF4),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    AppIcons.person,
                                    size: 72,
                                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.72),
                              ],
                              stops: const [0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      if (badgeVariant == _PopularBadgeVariant.availableToday)
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '本日空き',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.eye,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${8 + user.userId.hashCode % 15}人が閲覧中',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: UserFavoriteButton(targetUserId: user.userId),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black26,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    AppIcons.verified,
                                    size: 16,
                                    color: Color(0xFF1DA1F2),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  AppIcons.location_on,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    loc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '¥${nf.format(price)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '/h',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.star,
                                  size: 12,
                                  color: Color(0xFFFFB300),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  user.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularUserItem {
  const _PopularUserItem({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.hourlyRate,
    required this.location,
    required this.isVerified,
    required this.rating,
    required this.bio,
    required this.categoryLabel,
    required this.sortDate,
  });

  final String userId;
  final String displayName;
  final String photoUrl;
  final int? hourlyRate;
  final String location;
  final bool isVerified;
  final double rating;
  final String bio;
  /// Firestore `users.category` (same string as category listings filter).
  final String categoryLabel;
  /// `createdAt` / `updatedAt` for ordering (see [_NewUserItem.sortDate]).
  final DateTime sortDate;

  factory _PopularUserItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final base = _NewUserItem.fromDoc(doc);
    final data = doc.data() ?? const <String, dynamic>{};
    var rating = 4.6;
    if (data['rating'] is num) {
      rating = (data['rating'] as num).toDouble();
    } else if (data['averageRating'] is num) {
      rating = (data['averageRating'] as num).toDouble();
    } else {
      rating = 4.5 + (doc.id.hashCode % 10) / 10;
    }
    if (rating > 5) rating = 5;
    if (rating < 1) rating = 4.5;

    String bio = '';
    for (final k in ['bio', 'about', 'description', 'tagline']) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) {
        bio = v.trim();
        break;
      }
    }
    if (bio.isEmpty) {
      bio = '気軽に相談してください。';
    }

    final categoryLabel = (data['category'] as String?)?.trim() ?? '';

    return _PopularUserItem(
      userId: base.userId,
      displayName: base.displayName,
      photoUrl: base.photoUrl,
      hourlyRate: base.hourlyRate,
      location: base.location,
      isVerified: base.isVerified,
      rating: rating,
      bio: bio,
      categoryLabel: categoryLabel,
      sortDate: base.sortDate,
    );
  }
}

class _NewUserItem {
  const _NewUserItem({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.sortDate,
    this.hourlyRate,
    this.location = '',
    this.isVerified = false,
  });

  final String userId;
  final String displayName;
  final String photoUrl;
  final DateTime sortDate;
  final int? hourlyRate;
  final String location;
  final bool isVerified;

  factory _NewUserItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rateRaw = data['hourlyRate'];
    final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];
    return _NewUserItem(
      userId: doc.id,
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      photoUrl: (data['photoURL'] as String?)?.trim() ?? '',
      sortDate: _readDate(data['createdAt']) ??
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hourlyRate: rateRaw is num ? rateRaw.toInt() : null,
      location: (data['location'] as String?)?.trim() ??
          (data['area'] as String?)?.trim() ??
          (data['prefecture'] as String?)?.trim() ??
          '',
      isVerified: verifiedRaw == true,
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
