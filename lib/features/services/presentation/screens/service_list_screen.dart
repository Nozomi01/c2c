import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_list_provider.dart';
import '../widgets/service_card.dart';
import '../../../../widgets/shimmer_list.dart';
import '../../../../core/config/app_theme.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchController.text = q;
      _query = q;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(recommendedServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サービス一覧'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recommendedServicesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'キーワードで検索',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                final q = _query.toLowerCase();
                final filtered = q.isEmpty
                    ? services
                    : services
                        .where((s) =>
                            s.title.toLowerCase().contains(q) ||
                            s.description.toLowerCase().contains(q) ||
                            s.category.toLowerCase().contains(q))
                        .toList();

                if (filtered.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
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
                  padding: const EdgeInsets.all(16),
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

