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
        height: 76,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.borderStrong,
              width: AppDimensions.borderWidth,
            ),
          ),
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
              icon: Icons.auto_stories_rounded,
              label: 'Subjects',
              tooltip: 'Subjects',
              isActive: location == RouteNames.learningPath,
              onTap: () => context.go(RouteNames.learningPath),
            ),
            _PracticeNavItem(
              isActive: location == RouteNames.practice,
              onTap: () => context.go(RouteNames.practice),
            ),
            _BottomNavItem(
              icon: Icons.emoji_events_rounded,
              label: 'Leaderboard',
              tooltip: 'Leaderboard',
              isActive: location == RouteNames.leaderboard,
              onTap: () => context.go(RouteNames.leaderboard),
            ),
            _BottomNavItem(
              icon: Icons.person_rounded,
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
    final color = isActive ? colors.primary : colors.textMuted;

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
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  width: isActive ? 52 : 44,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: AppDimensions.radiusSm,
                    border: Border.all(
                      color: isActive
                          ? colors.primary.withValues(alpha: 0.7)
                          : Colors.transparent,
                      width: AppDimensions.borderWidth,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: isActive ? 1.12 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.badge.copyWith(
                    color: color,
                    fontSize: 11,
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
          message: 'Play',
          child: InkWell(
            borderRadius: AppDimensions.radiusCircular,
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(bottom: AppDimensions.raisedDepth),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(colors.primary, Colors.white, 0.18)!,
                    colors.primary,
                    colors.violet,
                  ],
                ),
                border: Border.all(
                  color: colors.primaryDark,
                  width: AppDimensions.borderWidth + 1,
                ),
                boxShadow: [
                  ...AppElevation.raised(
                    colors.primaryDark,
                    depth: AppDimensions.raisedDepth,
                  ),
                  if (isActive) ...AppElevation.glow(colors.primary),
                ],
              ),
              child: Icon(
                Icons.sports_esports_rounded,
                color: colors.primaryForeground,
                size: isActive ? 32 : 30,
                shadows: const [
                  Shadow(color: Color(0x40000000), offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
