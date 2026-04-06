import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMessageDot = ref.watch(hasAnyChatUnreadProvider);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        backgroundColor: AppColors.background,
        body: navigationShell,
        bottomNavigationBar: Material(
          type: MaterialType.transparency,
          elevation: 0,
          color: Colors.transparent,
          shadowColor: Colors.transparent,
          child: _FloatingPillBottomBar(
            currentIndex: navigationShell.currentIndex,
            onTap: _onItemTapped,
            showMessagesBadge: showMessageDot,
          ),
        ),
      ),
    );
  }
}

class _FloatingPillBottomBar extends StatelessWidget {
  const _FloatingPillBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.showMessagesBadge,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showMessagesBadge;

  /// Total visual height of the white pill (not counting outer vertical padding).
  static const double _pillHeight = 58;
  static const double _iconSize = 23;
  static const Color _inactiveIcon = Color(0xFF9CA3AF);
  static const Color _badgeRed = Color(0xFFFF3B30);
  static const Color _pillBorder = Color(0xFFE5E7EB);

  static const List<_NavItemSpec> _specs = [
    _NavItemSpec(
      label: '探す',
      iconInactive: AppIcons.navHomeInactive,
      iconActive: AppIcons.navHomeActive,
    ),
    _NavItemSpec(
      label: '予約',
      iconInactive: AppIcons.navReservationInactive,
      iconActive: AppIcons.navReservationActive,
    ),
    _NavItemSpec(
      label: '掲示板',
      iconInactive: AppIcons.navBoardInactive,
      iconActive: AppIcons.navBoardActive,
    ),
    _NavItemSpec(
      label: 'メッセージ',
      iconInactive: AppIcons.navMessageInactive,
      iconActive: AppIcons.navMessageActive,
      showBadgeWhenUnread: true,
    ),
    _NavItemSpec(
      label: 'マイページ',
      iconInactive: AppIcons.navProfileInactive,
      iconActive: AppIcons.navProfileActive,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topGap = 8.0;

    final radius = BorderRadius.circular(_pillHeight / 2);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topGap, 16, 10 + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: radius,
              border: Border.all(color: _pillBorder, width: 1),
            ),
            child: SizedBox(
              height: _pillHeight,
              child: Row(
                children: [
                  for (var i = 0; i < _specs.length; i++)
                    Expanded(
                      child: _PillNavItem(
                        spec: _specs[i],
                        selected: currentIndex == i,
                        showBadge: _specs[i].showBadgeWhenUnread &&
                            showMessagesBadge &&
                            currentIndex != i,
                        onTap: () {
                          if (currentIndex != i) {
                            HapticFeedback.selectionClick();
                          }
                          onTap(i);
                        },
                        pillHeight: _pillHeight,
                        iconSize: _iconSize,
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

class _NavItemSpec {
  const _NavItemSpec({
    required this.label,
    required this.iconInactive,
    required this.iconActive,
    this.showBadgeWhenUnread = false,
  });

  final String label;
  final IconData iconInactive;
  final IconData iconActive;
  final bool showBadgeWhenUnread;
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.spec,
    required this.selected,
    required this.showBadge,
    required this.onTap,
    required this.pillHeight,
    required this.iconSize,
  });

  final _NavItemSpec spec;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;
  final double pillHeight;
  final double iconSize;

  static const Color _inactiveIcon = _FloatingPillBottomBar._inactiveIcon;
  static const Color _badgeRed = _FloatingPillBottomBar._badgeRed;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? spec.iconActive : spec.iconInactive;
    final iconColor = selected ? AppColors.textPrimary : _inactiveIcon;

    final iconCore = Icon(icon, size: iconSize, color: iconColor);

    final iconWidget = showBadge
        ? SizedBox(
            width: iconSize + 4,
            height: iconSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconCore,
                Positioned(
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _badgeRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : iconCore;

    return Semantics(
      button: true,
      label: spec.label,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.black.withValues(alpha: 0.06),
          highlightColor: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(pillHeight / 2),
          child: SizedBox(
            height: pillHeight,
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}
