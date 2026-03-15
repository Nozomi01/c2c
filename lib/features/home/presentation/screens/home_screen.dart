import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              child: _SectionHeader(title: '新着ユーザーから探す', onTap: () {}),
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
                title: '新着出品から探す',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: (_) => _goToSearch(),
          decoration: InputDecoration(
            hintText: 'サービスを検索',
            hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            prefixIcon: Icon(
              Icons.search,
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
          icon: const Icon(Icons.notifications_outlined, size: 26),
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
                borderRadius: BorderRadius.all(Radius.circular(9)),
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

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['VA', 'OKANE', 'RK LLC', 'ISO', 'K'].map((label) {
          return Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          );
        }).toList(),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
                Icons.arrow_forward_ios,
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

  static const _placeholderNames = ['中村麻里子', '山田花子', '佐藤美咲', '鈴木さくら', '高橋あおい'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _placeholderNames.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
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
                  child: const Icon(
                    Icons.person,
                    size: 28,
                    color: Color(0xFF64B5F6),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    _placeholderNames[index],
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
          );
        },
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    ('💬 トーク・雑談', 'トーク・雑談', Color(0xFFFFF9C4)),
    ('💡 相談・アドバイス', '相談・アドバイス', Color(0xFFB3E5FC)),
    ('☕ カフェ・ご飯', 'カフェ・ご飯', Color(0xFFF8BBD9)),
    ('🎮 趣味・遊び', '趣味・遊び', Color(0xFFE1BEE7)),
    ('🚶 お出かけ・同行', 'お出かけ・同行', Color(0xFFC8E6C9)),
    ('🌟 その他', 'その他', Color(0xFFFFCCBC)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: List.generate(_categories.length, (index) {
          final (label, categoryKey, color) = _categories[index];
          return InkWell(
            onTap: () {
              context.push('/listings/category?name=$categoryKey');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NewListingCard extends StatelessWidget {
  const _NewListingCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty ? service.images.first : null;
    return InkWell(
      onTap: () => context.push('/services/${service.id}'),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 140,
                height: 120,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.primarySoft,
                        child: const Icon(
                          Icons.image,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.broken_image_outlined, color: AppColors.primary, size: 40),
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
