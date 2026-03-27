import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/config/app_theme.dart';

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: List.generate(
            itemCount,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.listHorizontal, vertical: AppSpacing.sm),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

