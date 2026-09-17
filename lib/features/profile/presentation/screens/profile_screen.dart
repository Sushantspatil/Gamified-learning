import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
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
    final colors = context.themeColors;

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
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.primary, colors.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.24),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: colors.surfaceElevated,
                        child: Icon(
                          AvatarCatalog.iconFor(profile.avatarId),
                          size: 48,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
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
                      child: Text(
                        [
                          if (profile.classLevel != null)
                            'Class ${profile.classLevel}',
                          if (profile.board != null) profile.board!,
                        ].join(' - '),
                        style: context.appTextStyles.titleMedium,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ProfileStatChip(
                        icon: Icons.monetization_on,
                        iconColor: AppColors.coinGold,
                        label: '${wallet?.coins ?? 0} Coins',
                      ),
                      ProfileStatChip(
                        icon: Icons.diamond,
                        iconColor: AppColors.gemCyan,
                        label: '${wallet?.gems ?? 0} Gems',
                      ),
                      ProfileStatChip(
                        icon: Icons.bolt,
                        iconColor: AppColors.xpPurple,
                        label: 'Level ${profile.level} - ${profile.xp} XP',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Edit Profile',
                    onPressed: () => context.push(RouteNames.editProfile),
                  ),
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
