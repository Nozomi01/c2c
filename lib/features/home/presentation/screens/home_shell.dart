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
    const size = 24.0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      bottomNavigationBar: isIOS
          ? CupertinoTabBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => _onItemTapped(context, index),
              activeColor: AppColors.textPrimary,
              inactiveColor: AppColors.textSecondary,
              backgroundColor: Colors.white,
              iconSize: size,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.navHomeInactive, size: size),
                  activeIcon: Icon(AppIcons.navHomeActive, size: size),
                  label: 'ホーム',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.navReservationInactive, size: size),
                  activeIcon: Icon(AppIcons.navReservationActive, size: size),
                  label: '予約',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.navBoardInactive, size: size),
                  activeIcon: Icon(AppIcons.navBoardActive, size: size),
                  label: '掲示板',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.navMessageInactive, size: size),
                  activeIcon: Icon(AppIcons.navMessageActive, size: size),
                  label: 'メッセージ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(AppIcons.navProfileInactive, size: size),
                  activeIcon: Icon(AppIcons.navProfileActive, size: size),
                  label: 'マイページ',
                ),
              ],
            )
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(
                      size: size,
                      color: AppColors.textPrimary,
                    );
                  }
                  return const IconThemeData(
                    size: size,
                    color: AppColors.textSecondary,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    );
                  }
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => _onItemTapped(context, index),
                height: 64,
                elevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                indicatorColor: AppColors.primarySoft,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(AppIcons.navHomeInactive, size: size),
                    selectedIcon: Icon(AppIcons.navHomeActive, size: size),
                    label: 'ホーム',
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.navReservationInactive, size: size),
                    selectedIcon: Icon(AppIcons.navReservationActive, size: size),
                    label: '予約',
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.navBoardInactive, size: size),
                    selectedIcon: Icon(AppIcons.navBoardActive, size: size),
                    label: '掲示板',
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.navMessageInactive, size: size),
                    selectedIcon: Icon(AppIcons.navMessageActive, size: size),
                    label: 'メッセージ',
                  ),
                  NavigationDestination(
                    icon: Icon(AppIcons.navProfileInactive, size: size),
                    selectedIcon: Icon(AppIcons.navProfileActive, size: size),
                    label: 'マイページ',
                  ),
                ],
              ),
            ),
    );
  }
}
