import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/presentation/providers/service_list_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(recommendedServicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.listHorizontal, AppSpacing.md, AppSpacing.listHorizontal, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: _SearchBar()),
                    const SizedBox(width: 8),
                    _NotificationButton(),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: _PromoBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '新着ユーザーから探す',
                onTap: () => context.go('/listings'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _NewUsersRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'カテゴリから探す', onTap: () {}),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _CategoryGrid()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '掲示板から探す',
                onTap: () => context.go('/listings'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: servicesAsync.when(
                  data: (services) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _NewListingCard(service: services[index]),
                        ),
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      '読み込みに失敗しました',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: (_) => _goToSearch(),
          decoration: InputDecoration(
            hintText: 'ユーザーを検索',
            hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            prefixIcon: Icon(
              Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoIcons.search
                  : AppIcons.search,
              size: 22,
              color: AppColors.textSecondary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }
}

class _NotificationButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final showBadge = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: Icon(
            Theme.of(context).platform == TargetPlatform.iOS
                ? CupertinoIcons.bell
                : AppIcons.notifications_outlined,
            size: 26,
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
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PromoBanner extends StatefulWidget {
  const _PromoBanner();

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  static const _banners = [
    _BannerItem(
      imagePath: 'assets/images/logo_text.png',
      title: 'まずは気軽に話してみよう',
      subtitle: '今すぐ相談できる相手を見つける',
    ),
    _BannerItem(
      imagePath: 'assets/images/logo.png',
      title: 'あなたの得意を出品しよう',
      subtitle: '時給を設定して掲示板で募集',
    ),
    _BannerItem(
      imagePath: 'assets/images/phone.png',
      title: 'スマホだけでかんたんスタート',
      subtitle: 'プロフィールを作ってすぐ始める',
    ),
  ];

  late final PageController _pageController;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_current + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _banners.length,
                onPageChanged: (index) {
                  if (_current != index) {
                    setState(() => _current = index);
                  }
                },
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        banner.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE9ECF2),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xAA000000), Color(0x22000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              banner.subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              final selected = index == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? AppColors.textPrimary : const Color(0xFFD5D9E1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BannerItem {
  const _BannerItem({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  final String imagePath;
  final String title;
  final String subtitle;
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
                Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoIcons.chevron_right
                    : AppIcons.chevron_right,
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
                                  Theme.of(context).platform == TargetPlatform.iOS
                                      ? CupertinoIcons.person_fill
                                      : AppIcons.person,
                                  size: 28,
                                  color: const Color(0xFF64B5F6),
                                )
                              : CachedNetworkImage(
                                  imageUrl: user.photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Theme.of(context).platform == TargetPlatform.iOS
                                        ? CupertinoIcons.person_fill
                                        : AppIcons.person,
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

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    (_CategoryIconSet(CupertinoIcons.chat_bubble_2, AppIcons.chat_bubble_outline), 'トーク・雑談', Color(0xFFFFF9C4)),
    (_CategoryIconSet(CupertinoIcons.lightbulb, AppIcons.lightbulb_outline), '相談・アドバイス', Color(0xFFB3E5FC)),
    (_CategoryIconSet(CupertinoIcons.bag, AppIcons.restaurant_outlined), 'カフェ・ご飯', Color(0xFFF8BBD9)),
    (_CategoryIconSet(CupertinoIcons.game_controller, AppIcons.sports_esports_outlined), '趣味・遊び', Color(0xFFE1BEE7)),
    (_CategoryIconSet(CupertinoIcons.person_2, AppIcons.person_outline), 'お出かけ・同行', Color(0xFFC8E6C9)),
    (_CategoryIconSet(CupertinoIcons.star, AppIcons.star_border), 'その他', Color(0xFFFFCCBC)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: List.generate(_categories.length, (index) {
          final (iconSet, categoryKey, color) = _categories[index];
          final icon = Theme.of(context).platform == TargetPlatform.iOS
              ? iconSet.ios
              : iconSet.android;
          return InkWell(
            onTap: () {
              context.push('/listings/category?name=$categoryKey');
            },
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryKey,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CategoryIconSet {
  const _CategoryIconSet(this.ios, this.android);

  final IconData ios;
  final IconData android;
}

class _NewListingCard extends StatelessWidget {
  const _NewListingCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return InkWell(
      onTap: () => context.push('/services/${service.id}'),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: SizedBox(
                width: 140,
                height: 120,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.primarySoft,
                        child: Icon(
                          Theme.of(context).platform == TargetPlatform.iOS
                              ? CupertinoIcons.photo
                              : AppIcons.image,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primarySoft,
                          child: Icon(
                            Theme.of(context).platform == TargetPlatform.iOS
                                ? CupertinoIcons.photo_fill_on_rectangle_fill
                                : AppIcons.broken_image_outlined,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${service.price} / 時間',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
