import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../domain/models/service.dart';
import '../providers/service_detail_provider.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return Scaffold(
      appBar: AppBar(),
      body: serviceAsync.when(
        data: (service) => _Content(service: service),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラーが発生しました: $e')),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ImagePager(images: service.images),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.location,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '¥${service.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${service.duration}分',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'サービス内容',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(service.description),
                const SizedBox(height: 16),
                const Text(
                  '対応方法',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (service.onlineAvailable)
                      const Chip(label: Text('オンライン')),
                    if (service.offlineAvailable)
                      const Chip(label: Text('対面')),
                  ],
                ),
              ],
            ),
          ),
        ),
        _BottomBar(service: service),
      ],
    );
  }
}

class _ImagePager extends StatelessWidget {
  const _ImagePager({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 240,
        color: AppColors.primarySoft,
        child: const Center(
          child: Icon(
            Icons.person,
            size: 64,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return CachedNetworkImage(
            imageUrl: images[index],
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // TODO: favorite
            },
            icon: const Icon(Icons.favorite_border),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              // TODO: open chat (after purchase)
            },
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {
                context.pushNamed(
                  'transactionDetail',
                  pathParameters: {'id': 'new'},
                  extra: service,
                );
              },
              child: const Text('購入手続きへ'),
            ),
          ),
        ],
      ),
    );
  }
}

