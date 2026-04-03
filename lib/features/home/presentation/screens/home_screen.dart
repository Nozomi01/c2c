import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 0 = すべて, 1 = カフェ・お茶, 2 = 悩み相談
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.listHorizontal,
                  AppSpacing.md,
                  AppSpacing.listHorizontal,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _SearchBar()),
                    const SizedBox(width: 10),
                    _BlackFilterButton(onPressed: _openFilter),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _HomeQuickChips(
                selectedIndex: _selectedQuickChip,
                onFilterTap: _openFilter,
                onSelect: (index) {
                  setState(() => _selectedQuickChip = index);
                  switch (index) {
                    case 0:
                      _openListings();
                      break;
                    case 1:
                      _openListings('カフェ・お茶');
                      break;
                    case 2:
                      _openListings('悩み相談');
                      break;
                  }
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '新着ユーザーから探す',
                onTap: () => context.go('/listings'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _NewUsersRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    return Material(
      color: AppColors.textPrimary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            AppIcons.slider_horizontal_3,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
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
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final showBadge = unreadCount > 0;

    return Material(
      color: const Color(0xFFEBEDF0),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: _controller,
        onSubmitted: (_) => _goToSearch(),
        decoration: InputDecoration(
          hintText: 'キーワードやエリアで検索',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          prefixIcon: Icon(
            AppIcons.search,
            size: 20,
            color: AppColors.textSecondary.withValues(alpha: 0.75),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: Icon(
                    AppIcons.notifications_outlined,
                    size: 22,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: unreadCount > 99 ? 4 : (unreadCount > 9 ? 4 : 5),
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(AppRadii.xs)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        textInputAction: TextInputAction.search,
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.listHorizontal, 0, AppSpacing.listHorizontal, 0),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterIconChip(onTap: onFilterTap),
          ),
          _TextChip(
            label: 'すべて',
            selected: selectedIndex == 0,
            icon: null,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 8),
          _TextChip(
            label: '☕️ カフェ・お茶',
            selected: selectedIndex == 1,
            icon: AppIcons.home_row_cafe,
            onTap: () => onSelect(1),
          ),
          const SizedBox(width: 8),
          _TextChip(
            label: '💬 悩み相談',
            selected: selectedIndex == 2,
            icon: AppIcons.home_row_consult,
            onTap: () => onSelect(2),
          ),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E5EB)),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.home_chip_filter,
            size: 18,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
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
    this.icon,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.textPrimary : Colors.white;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final border = selected ? AppColors.textPrimary : const Color(0xFFE2E5EB);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: selected ? 0 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
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
                size: 22,
                color: const Color(0xFF1976D2),
              ),
              const SizedBox(width: 8),
              const Text(
                'カテゴリから探す',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Icon(
                AppIcons.chevron_right,
                size: 16,
                color: AppColors.textSecondary,
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
      label: '趣味',
      icon: AppIcons.home_row_hobby_entertainment,
      categoryName: '趣味・エンタメ',
      iconColor: Color(0xFFC2185B),
      bg: Color(0xFFFCE4EC),
    ),
    _CategoryShortcut(
      label: '写真',
      icon: AppIcons.home_row_photo_sns,
      categoryName: '写真・SNS',
      iconColor: Color(0xFF00695C),
      bg: Color(0xFFE0F2F1),
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

class _PromoBannerStrip extends StatelessWidget {
  const _PromoBannerStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 158,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
        children: [
          _GradientPromoCard(
            badge: '期間限定',
            title: '初回利用 1,000円OFF!',
            subtitle: '今すぐチェック',
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8E7CC3), Color(0xFF6B5B95)],
            ),
            accent: Color(0xFFB39DDB),
          ),
          SizedBox(width: 12),
          _GradientPromoCard(
            badge: 'おすすめ',
            title: '気になる相手を見つけよう',
            subtitle: 'プロフィールをのぞいてみる',
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE57373), Color(0xFFC62828)],
            ),
            accent: Color(0xFFFFCDD2),
          ),
        ],
      ),
    );
  }
}

class _GradientPromoCard extends StatelessWidget {
  const _GradientPromoCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accent,
  });

  final String badge;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - AppSpacing.listHorizontal * 2 - 48;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width.clamp(280.0, 400.0),
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -8,
              bottom: -12,
              child: Icon(
                AppIcons.home_promo_gift,
                size: 120,
                color: accent.withValues(alpha: 0.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: Material(
              color: const Color(0xFFE0E0E0),
              child: InkWell(
                onTap: () => context.push('/people/${user.userId}'),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (user.photoUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: user.photoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFFBDBDBD)),
                        )
                      else
                        Container(color: const Color(0xFFBDBDBD)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            stops: const [0, 0.42, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(AppIcons.star, size: 15, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Text(
                                '今週のピックアップ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Material(
                          color: const Color(0xFF2196F3),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {},
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                AppIcons.favorite_border,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: Text(
                          user.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                AppIcons.chevron_right,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewUsersRow extends StatelessWidget {
  const _NewUsersRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(40).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                '新着ユーザーを取得できませんでした',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final users = (snapshot.data?.docs ?? const [])
            .map(_NewUserItem.fromDoc)
            .where((u) => u.displayName.isNotEmpty)
            .toList();

        users.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        final newUsers = users.take(12).toList();

        if (newUsers.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                '表示できるユーザーがいません',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
            itemCount: newUsers.length,
            itemBuilder: (context, index) {
              final user = newUsers[index];
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.listHorizontal),
                child: InkWell(
                  onTap: () => context.push('/people/${user.userId}'),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE3F2FD),
                          border: Border.all(
                            color: const Color(0xFFBBDEFB),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: user.photoUrl.isEmpty
                              ? Icon(
                                  AppIcons.person,
                                  size: 28,
                                  color: const Color(0xFF64B5F6),
                                )
                              : CachedNetworkImage(
                                  imageUrl: user.photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    AppIcons.person,
                                    size: 28,
                                    color: const Color(0xFF64B5F6),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 72,
                        child: Text(
                          user.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NewUserItem {
  const _NewUserItem({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.sortDate,
  });

  final String userId;
  final String displayName;
  final String photoUrl;
  final DateTime sortDate;

  factory _NewUserItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _NewUserItem(
      userId: doc.id,
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      photoUrl: (data['photoURL'] as String?)?.trim() ?? '',
      sortDate: _readDate(data['createdAt']) ??
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
