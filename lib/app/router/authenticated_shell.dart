import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_elevation.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';
import '../theme/app_typography.dart';
import 'route_names.dart';

class AuthenticatedShell extends StatelessWidget {
  final Widget child;

  const AuthenticatedShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _AuthenticatedBottomNavigation(),
    );
  }
}

class _AuthenticatedBottomNavigation extends StatelessWidget {
  const _AuthenticatedBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final location = GoRouterState.of(context).matchedLocation;

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surfaceElevated],
          ),
          border: Border(top: BorderSide(color: colors.borderStrong)),
          boxShadow: AppElevation.shadows(colors, 2),
        ),
        child: Row(
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              tooltip: 'Home',
              isActive: location == RouteNames.dashboard,
              onTap: () => context.go(RouteNames.dashboard),
            ),
            _BottomNavItem(
              icon: Icons.menu_book_outlined,
              label: 'Learn',
              tooltip: 'Learn',
              isActive: location == RouteNames.learningPath,
              onTap: () => context.go(RouteNames.learningPath),
            ),
            _PracticeNavItem(
              isActive: location == RouteNames.practice,
              onTap: () => context.go(RouteNames.practice),
            ),
            _BottomNavItem(
              icon: Icons.leaderboard_outlined,
              label: 'Rank',
              tooltip: 'Rank',
              isActive: location == RouteNames.leaderboard,
              onTap: () => context.go(RouteNames.leaderboard),
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              tooltip: 'Profile',
              isActive: location == RouteNames.profile,
              onTap: () => context.go(RouteNames.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final color = isActive ? colors.primary : colors.textSecondary;

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: AppDimensions.radiusCircular,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _PracticeNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Expanded(
      child: Center(
        child: Tooltip(
          message: 'Practice',
          child: InkWell(
            borderRadius: AppDimensions.radiusCircular,
            onTap: onTap,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.violet],
                ),
                border: Border.all(
                  color: colors.primaryForeground.withValues(alpha: 0.24),
                ),
                boxShadow: AppElevation.shadows(colors, 2),
              ),
              child: Icon(
                Icons.sports_esports,
                color: colors.primaryForeground,
                size: isActive ? 28 : 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
