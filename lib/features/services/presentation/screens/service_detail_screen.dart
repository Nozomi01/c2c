import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/models/service.dart';
import '../providers/service_detail_provider.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: serviceAsync.when(
        data: (service) => _Content(
          service: service,
          onChatPressed: () => _openChat(context, ref, service),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラーが発生しました: $e')),
      ),
    );
  }

  static Future<void> _openChat(BuildContext context, WidgetRef ref, Service service) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == service.ownerId) return;
    final chatId = await ref.read(chatRepositoryProvider).findOrCreateChat(user.uid, service.ownerId);
    if (context.mounted) context.push('/chats/$chatId');
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.service, required this.onChatPressed});

  final Service service;
  final VoidCallback onChatPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImageHeader(images: service.images),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¥${NumberFormat('#,###').format(service.price)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            service.category,
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _formatRelativeTime(service.createdAt),
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ProductInfoBox(service: service),
                      const SizedBox(height: 20),
                      _SellerSection(ownerId: service.ownerId),
                      const SizedBox(height: 20),
                      const Text(
                        '商品の詳細',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(service: service, onChatPressed: onChatPressed),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}日前';
    if (diff.inHours > 0) return '${diff.inHours}時間前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分前';
    return 'たった今';
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: images.isEmpty
              ? Container(
                  color: AppColors.primarySoft,
                  child: const Center(
                    child: Icon(Icons.image, size: 64, color: AppColors.primary),
                  ),
                )
              : PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) => CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.primary, size: 48),
                    ),
                  ),
                ),
        ),
        Positioned(
          left: 16,
          top: MediaQuery.of(context).padding.top + 8,
          child: _CircleIconButton(
            icon: Icons.arrow_back,
            onPressed: () => context.pop(),
          ),
        ),
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 8,
          child: _CircleIconButton(
            icon: Icons.share_outlined,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ProductInfoBox extends StatelessWidget {
  const _ProductInfoBox({required this.service});

  final Service service;

  String get _durationLabel {
    if (service.duration < 60) return '${service.duration}分';
    if (service.duration == 60) return '1時間';
    final h = service.duration ~/ 60;
    final m = service.duration % 60;
    if (m == 0) return '${h}時間';
    return '${h}時間${m}分';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '商品の情報',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: '実施形式',
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (service.onlineAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade700),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('オンライン', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                  ),
                if (service.offlineAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81C784),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('対面', style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: '実施場所',
            child: Text(
              '${service.location}${service.onlineAvailable ? ' (オンラインも可)' : ''}',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: '実施日程',
            child: Text(
              '要相談',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: '所要時間',
            child: Text(_durationLabel, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _SellerSection extends StatelessWidget {
  const _SellerSection({required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(ownerId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['displayName'] as String?)?.trim();
        final displayName = (name == null || name.isEmpty) ? '出品者' : name;

        return Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primarySoft,
              child: const Icon(Icons.person, size: 32, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (_) => const Icon(Icons.star, size: 16, color: Color(0xFFFFB300)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '–',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.service, required this.onChatPressed});

  final Service service;
  final VoidCallback onChatPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.favorite_border, size: 24),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onChatPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.mail_outline, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                context.pushNamed(
                  'serviceRequest',
                  pathParameters: {'id': service.id},
                );
              },
              icon: const Icon(Icons.assignment, size: 20),
              label: const Text('サービスを依頼'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
