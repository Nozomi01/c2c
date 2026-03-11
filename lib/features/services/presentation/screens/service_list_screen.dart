import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_list_provider.dart';
import '../widgets/service_card.dart';
import '../../../../widgets/shimmer_list.dart';

class ServiceListScreen extends ConsumerWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            servicesAsync.when(
              data: (services) => SliverList.separated(
                itemCount: services.length,
                itemBuilder: (context, index) =>
                    ServiceCard(service: services[index]),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
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
      ),
    );
  }
}

