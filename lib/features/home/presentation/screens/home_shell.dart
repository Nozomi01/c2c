import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';

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
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
        child: Icon(isIOS ? CupertinoIcons.add : AppIcons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: isIOS
          ? CupertinoTabBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => _onItemTapped(context, index),
              activeColor: AppColors.textPrimary,
              inactiveColor: AppColors.textSecondary,
              backgroundColor: Colors.white,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.home),
                  activeIcon: Icon(CupertinoIcons.house_fill),
                  label: 'ホーム',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.square_list),
                  activeIcon: Icon(CupertinoIcons.square_list_fill),
                  label: '掲示板',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.chat_bubble),
                  activeIcon: Icon(CupertinoIcons.chat_bubble_fill),
                  label: 'メッセージ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.person),
                  activeIcon: Icon(CupertinoIcons.person_fill),
                  label: 'マイページ',
                ),
              ],
            )
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onItemTapped(context, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(AppIcons.home_outlined),
                  selectedIcon: Icon(AppIcons.home),
                  label: 'ホーム',
                ),
                NavigationDestination(
                  icon: Icon(AppIcons.list_alt_outlined),
                  selectedIcon: Icon(AppIcons.list_alt),
                  label: '掲示板',
                ),
                NavigationDestination(
                  icon: Icon(AppIcons.chat_bubble_outline),
                  selectedIcon: Icon(AppIcons.chat_bubble),
                  label: 'メッセージ',
                ),
                NavigationDestination(
                  icon: Icon(AppIcons.person_outline),
                  selectedIcon: Icon(AppIcons.person),
                  label: 'マイページ',
                ),
              ],
            ),
    );
  }
}
