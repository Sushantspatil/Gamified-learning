import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../cosmetics/presentation/cosmetic_color_catalog.dart';
import '../../../cosmetics/presentation/providers/cosmetics_providers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load profile.', style: context.appTextStyles.bodyLarge),
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
                child: Text('No profile data available.', style: context.appTextStyles.bodyLarge),
              );
            }

            return SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(equippedColor == null ? 0 : 3),
                      decoration: equippedColor == null
                          ? null
                          : BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: equippedColor, width: 3),
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
                  Center(child: Text(user.displayName, style: context.appTextStyles.titleLarge)),
                  const SizedBox(height: AppSpacing.xs),
                  Center(child: Text(user.email, style: context.appTextStyles.bodyMedium)),
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
                  _ComingSoonSection(title: 'Achievements'),
                  const SizedBox(height: AppSpacing.md),
                  _NavSection(title: 'Cosmetics', onTap: () => context.push(RouteNames.cosmetics)),
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

class _ComingSoonSection extends StatelessWidget {
  final String title;

  const _ComingSoonSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.appTextStyles.titleMedium)),
          Text('Coming Soon', style: context.appTextStyles.labelSmall),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.appTextStyles.titleMedium)),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
