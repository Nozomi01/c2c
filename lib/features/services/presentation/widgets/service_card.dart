import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/domain/models/service.dart';
import '../../../../core/config/app_theme.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.pushNamed('serviceDetail', pathParameters: {'id': service.id});
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              _ImageThumbnail(url: service.images.isNotEmpty ? service.images.first : null),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.location,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            '¥${service.price}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${service.duration}分',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      child: SizedBox(
        width: 110,
        height: double.infinity,
        child: url == null
            ? Container(
                color: AppColors.primarySoft,
                child: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primarySoft,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.primary),
                ),
              ),
      ),
    );
  }
}

