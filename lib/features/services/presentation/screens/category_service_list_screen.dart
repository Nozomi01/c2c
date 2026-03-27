import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../providers/service_list_provider.dart';
import '../widgets/service_card.dart';
import '../../../../widgets/shimmer_list.dart';

class CategoryServiceListScreen extends ConsumerStatefulWidget {
  const CategoryServiceListScreen({
    super.key,
    required this.category,
  });

  final String category;

  @override
  ConsumerState<CategoryServiceListScreen> createState() =>
      _CategoryServiceListScreenState();
}

class _CategoryServiceListScreenState
    extends ConsumerState<CategoryServiceListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync =
        ref.watch(servicesByCategoryProvider(widget.category));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.category,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(servicesByCategoryProvider(widget.category));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'キーワードで絞り込む',
                    prefixIcon: const Icon(AppIcons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim();
                    });
                  },
                ),
              ),
            ),
            servicesAsync.when(
              data: (services) {
                final filtered = _query.isEmpty
                    ? services
                    : services
                        .where((s) =>
                            s.title.contains(_query) ||
                            s.description.contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          '条件に合う出品がありません',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return SliverList.separated(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      ServiceCard(service: filtered[index]),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                );
              },
              loading: () => const ShimmerList(),
              error: (e, st) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Text('読み込みに失敗しました: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

