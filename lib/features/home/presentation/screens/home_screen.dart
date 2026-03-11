import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_theme.dart';
import '../../../services/presentation/providers/service_list_provider.dart';
import '../../../services/presentation/widgets/service_card.dart';
import 'package:c2c/widgets/section_header.dart';
import 'package:c2c/widgets/shimmer_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(recommendedServicesProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text(
              'ウォンティ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchBar(),
                  const SizedBox(height: 16),
                  _CategoryGrid(),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'おすすめサービス'),
                ],
              ),
            ),
          ),
          servicesAsync.when(
            data: (services) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: services.length,
                itemBuilder: (context, index) => ServiceCard(service: services[index]),
                separatorBuilder: (context, index) => const SizedBox(height: 12),
              ),
            ),
            loading: () => const ShimmerList(),
            error: (e, st) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('読み込みに失敗しました: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: () {
        // TODO: navigate to search screen
      },
      decoration: const InputDecoration(
        hintText: 'サービスを検索',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final categories = const [
    '話す・相談',
    'アドバイス',
    'カフェ・ご飯',
    '趣味・アクティビティ',
    'おでかけ',
    'その他',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final label = categories[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: navigate to filtered listing
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.favorite,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

