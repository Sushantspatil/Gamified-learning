import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final streak = ref.watch(streakControllerProvider).valueOrNull;

    return GameScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            96,
          ),
          children: [
            _ProfileHeader(
              displayName: user?.displayName ?? 'Learner',
              avatarId: profile?.avatarId ?? 'default',
              classLevel: profile?.classLevel,
              board: profile?.board,
              level: profile?.level ?? 1,
              streak: streak?.currentStreak ?? 0,
              gems: wallet?.gems ?? 0,
              onTap: () => context.go(RouteNames.profile),
            ),
            const SizedBox(height: AppSpacing.md),
            const _BackendQuizSection(),
            const SizedBox(height: AppSpacing.lg),
            _BackendStatsCard(
              coins: wallet?.coins ?? 0,
              gems: wallet?.gems ?? 0,
              xp: profile?.xp ?? 0,
              level: profile?.level ?? 1,
              streak: streak?.currentStreak ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String avatarId;
  final String? classLevel;
  final String? board;
  final int level;
  final int streak;
  final int gems;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.displayName,
    required this.avatarId,
    this.classLevel,
    this.board,
    required this.level,
    required this.streak,
    required this.gems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppPressable(
                key: const Key('compact_profile_header'),
                onTap: onTap,
                borderRadius: AppDimensions.radiusMd,
                child: Row(
                  children: [
                    AppAvatar(
                      fallbackIcon: AvatarCatalog.iconFor(avatarId),
                      size: AppDimensions.avatarSizeMd,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppBadge(
                            label: _subtitle,
                            variant: AppBadgeVariant.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const ThemeModeMenu(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetricPill(
                icon: Icons.local_fire_department,
                iconColor: AppColors.streakFire,
                value: streak,
                semanticLabel: 'Backend streak',
                tooltip: 'Backend streak',
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetricPill(
                icon: Icons.diamond,
                iconColor: AppColors.gemCyan,
                value: gems,
                semanticLabel: 'Backend gems',
                tooltip: 'Backend gems',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _subtitle {
    final details = [if (classLevel != null) 'Class $classLevel', ?board];
    if (details.isEmpty) return 'Level $level learner';
    return '${details.join(' - ')} - Level $level';
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String semanticLabel;
  final String tooltip;

  const _MetricPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.semanticLabel,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: semanticLabel,
        value: value.toString(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppDimensions.radiusCircular,
            border: Border.all(color: colors.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 17),
                const SizedBox(width: AppSpacing.xs),
                AnimatedCountText(
                  value: value,
                  style: context.appTextStyles.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendQuizSection extends StatelessWidget {
  const _BackendQuizSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: () =>
          context.push(RouteNames.quizPath('accounting', QuestionType.mcq)),
      borderRadius: AppDimensions.radiusLg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.violet],
          ),
          borderRadius: AppDimensions.radiusLg,
          boxShadow: AppElevation.shadows(colors, 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BACKEND QUIZ',
                    style: AppTypography.badge.copyWith(
                      color: colors.primaryForeground.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Book-Keeping & Accountancy',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.titleLarge.copyWith(
                      color: colors.primaryForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Questions, scoring, rewards, and progress come from the deployed backend.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.primaryForeground.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.arrow_forward_rounded,
              color: colors.primaryForeground,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendStatsCard extends StatelessWidget {
  final int coins;
  final int gems;
  final int xp;
  final int level;
  final int streak;

  const _BackendStatsCard({
    required this.coins,
    required this.gems,
    required this.xp,
    required this.level,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Backend profile', style: context.appTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _BackendStat(
                icon: Icons.monetization_on_outlined,
                label: 'Coins',
                value: coins,
                color: AppColors.coinGold,
              ),
              _BackendStat(
                icon: Icons.diamond_outlined,
                label: 'Gems',
                value: gems,
                color: AppColors.gemCyan,
              ),
              _BackendStat(
                icon: Icons.bolt_outlined,
                label: 'Level',
                value: level,
                color: AppColors.xpPurple,
              ),
              _BackendStat(
                icon: Icons.local_fire_department_outlined,
                label: 'Streak',
                value: streak,
                color: AppColors.streakFire,
              ),
              _BackendStat(
                icon: Icons.trending_up_outlined,
                label: 'XP',
                value: xp,
                color: context.themeColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackendStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _BackendStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.appTextStyles.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                AnimatedCountText(
                  value: value,
                  style: context.appTextStyles.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
