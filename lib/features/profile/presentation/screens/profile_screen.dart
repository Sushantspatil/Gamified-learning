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
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../cosmetics/presentation/cosmetic_color_catalog.dart';
import '../../../cosmetics/presentation/providers/cosmetics_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../../core/audio/audio_providers.dart';
import '../avatar_catalog.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_stat_chip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profileAsync = ref.watch(profileControllerProvider);
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final paths = ref.watch(learningPathsProvider).valueOrNull ?? const [];
    final cosmeticsState = ref.watch(cosmeticsControllerProvider).valueOrNull;
    final colors = context.themeColors;
    String? equippedColorKey;
    if (cosmeticsState != null && cosmeticsState.equippedId != null) {
      for (final item in cosmeticsState.catalog) {
        if (item.id == cosmeticsState.equippedId) {
          equippedColorKey = item.colorKey;
          break;
        }
      }
    }
    final equippedColor = CosmeticColorCatalog.colorFor(equippedColorKey);

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load profile.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(profileControllerProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) {
            if (user == null || profile == null) {
              return Center(
                child: Text(
                  'No profile data available.',
                  style: context.appTextStyles.bodyLarge,
                ),
              );
            }

            return SingleChildScrollView(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                equippedColor ?? colors.primary,
                                colors.secondary,
                              ],
                            ),
                            boxShadow: [
                              ...AppElevation.raised(
                                AppElevation.edgeColor(
                                  equippedColor ?? colors.primary,
                                ),
                                depth: AppDimensions.raisedDepth,
                              ),
                              ...AppElevation.glow(
                                equippedColor ?? colors.primary,
                                strength: 0.8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: colors.surfaceElevated,
                            child: Icon(
                              AvatarCatalog.iconFor(profile.avatarId),
                              size: 54,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.ms,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.warning,
                              borderRadius: AppDimensions.radiusCircular,
                              border: Border.all(
                                color: AppElevation.edgeColor(colors.warning),
                                width: AppDimensions.borderWidth,
                              ),
                            ),
                            child: Text(
                              'LV ${profile.level}',
                              style: AppTypography.badge.copyWith(
                                color: colors.textInverse,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      user.displayName,
                      style: context.appTextStyles.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      user.email,
                      style: context.appTextStyles.bodyMedium,
                    ),
                  ),
                  if (profile.classLevel != null || profile.board != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: AppSpacing.paddingMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (profile.classLevel != null)
                                'Class ${profile.classLevel}',
                              if (profile.board != null) profile.board!,
                            ].join(' - '),
                            style: context.appTextStyles.titleMedium,
                          ),
                          if (profile.selectedSubjectIds.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _subjectNames(paths, profile.selectedSubjectIds),
                              style: context.appTextStyles.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppPressable(
                        onTap: () => context.push(RouteNames.wallet),
                        child: ProfileStatChip(
                          icon: Icons.monetization_on,
                          iconColor: AppColors.coinGold,
                          label: '${wallet?.coins ?? 0} Coins',
                        ),
                      ),
                      AppPressable(
                        onTap: () => context.push(RouteNames.wallet),
                        child: ProfileStatChip(
                          icon: Icons.diamond,
                          iconColor: AppColors.gemCyan,
                          label: '${wallet?.gems ?? 0} Gems',
                        ),
                      ),
                      ProfileStatChip(
                        icon: Icons.bolt,
                        iconColor: AppColors.xpPurple,
                        label: 'Level ${profile.level} • ${profile.xp} XP',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Edit Profile',
                    onPressed: () => context.push(RouteNames.editProfile),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _ComingSoonSection(title: 'Achievements'),
                  const SizedBox(height: AppSpacing.md),
                  _NavSection(
                    title: 'Cosmetics',
                    onTap: () => context.push(RouteNames.cosmetics),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _AudioSettingsSection(),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Logout',
                    variant: AppButtonVariant.destructive,
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(RouteNames.login);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _subjectNames(List<LearningPath> paths, List<String> selectedIds) {
  final names = [
    for (final path in paths)
      if (selectedIds.contains(path.id)) path.title,
  ];
  return names.isEmpty
      ? '${selectedIds.length} subjects selected'
      : names.join(', ');
}

class _ComingSoonSection extends StatelessWidget {
  final String title;

  const _ComingSoonSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.appTextStyles.titleMedium),
          ),
          Icon(Icons.emoji_events_outlined, color: colors.warning, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text('Coming soon', style: context.appTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavSection({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: colors.violet, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: context.appTextStyles.titleMedium),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AudioSettingsSection extends ConsumerWidget {
  const _AudioSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.themeColors;
    final soundSettings = ref.watch(soundSettingsControllerProvider);

    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sound Settings',
                  style: context.appTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Sound Effects',
              style: context.appTextStyles.bodyMedium,
            ),
            subtitle: Text(
              'Game audio and interactive feedback',
              style: context.appTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            value: soundSettings.sfxEnabled,
            activeThumbColor: colors.primary,
            onChanged: (val) {
              ref.read(soundSettingsControllerProvider.notifier).toggleSfx(val);
            },
          ),
        ],
      ),
    );
  }
}
