import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onItemTapped(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 15),
        child: FloatingActionButton(
          onPressed: () => context.push('/create'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home,
                            label: 'ホーム',
                            isSelected: navigationShell.currentIndex == 0,
                            onTap: () => _onItemTapped(context, 0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.list_alt_outlined,
                            activeIcon: Icons.list_alt,
                            label: '掲示板',
                            isSelected: navigationShell.currentIndex == 1,
                            onTap: () => _onItemTapped(context, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 56),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.chat_bubble_outline,
                            activeIcon: Icons.chat_bubble,
                            label: 'メッセージ',
                            isSelected: navigationShell.currentIndex == 2,
                            onTap: () => _onItemTapped(context, 2),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.person_outline,
                            activeIcon: Icons.person,
                            label: 'マイページ',
                            isSelected: navigationShell.currentIndex == 3,
                            onTap: () => _onItemTapped(context, 3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
