import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../cosmetics/presentation/cosmetic_color_catalog.dart';
import '../../../cosmetics/presentation/providers/cosmetics_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../streaks/presentation/widgets/streak_week_row.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../achievements.dart';
import '../providers/profile_providers.dart';
import '../widgets/achievements_section.dart';
import '../widgets/profile_hero.dart';
import '../widgets/profile_stats_grid.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Goes up when a badge has just been unlocked, so the character cheers.
  int _celebrateTick = 0;
  String? _checkedSignature;

  /// Tells the player about badges they have not seen yet (once each).
  void _checkUnlocks(String userId, List<Achievement> items) {
    final unlocked = [
      for (final a in items)
        if (a.unlocked) a,
    ];
    final signature = unlocked.map((a) => a.id).join(',');
    if (signature == _checkedSignature) return;
    _checkedSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final LocalStorageService storage;
      try {
        storage = ref.read(localStorageServiceProvider);
      } catch (_) {
        return; // no storage in this context: skip the announcement
      }
      final key = 'seen_achievements_$userId';
      final seen = (storage.getString(key) ?? '')
          .split(',')
          .where((id) => id.isNotEmpty)
          .toSet();
      final fresh = unlocked.where((a) => !seen.contains(a.id)).toList();
      if (fresh.isEmpty) return;
      storage.setString(key, {...seen, ...unlocked.map((a) => a.id)}.join(','));
      setState(() => _celebrateTick++);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              fresh.length == 1
                  ? 'New badge unlocked: ${fresh.first.title}!'
                  : '${fresh.length} new badges unlocked!',
            ),
          ),
        );
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_logout'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profileAsync = ref.watch(profileControllerProvider);
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final streak = ref.watch(streakControllerProvider).valueOrNull;
    final rewards = ref.watch(rewardsProvider);
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

            final currentStreak = streak?.currentStreak ?? 0;
            final badges = computeAchievements(
              AchievementInputs(
                gamesPlayed: rewards.processedQuizIds.length,
                streak: currentStreak,
                level: profile.level,
                hasSpun: rewards.lastSpinDate != null,
                cosmeticsOwned:
                    rewards.ownedAvatars.length + rewards.ownedFrames.length,
              ),
            );
            _checkUnlocks(user.id, badges);

            final classLine = [
              if (profile.classLevel != null) 'Class ${profile.classLevel}',
              if (profile.board != null) profile.board!,
            ].join(' - ');

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHero(
                    name: user.displayName,
                    classLine: classLine.isEmpty ? null : classLine,
                    subjects: profile.selectedSubjectIds.isEmpty
                        ? null
                        : _subjectNames(paths, profile.selectedSubjectIds),
                    avatarId: profile.avatarId,
                    level: profile.level,
                    xp: profile.xp,
                    nextLevelXp: profile.nextLevelXp,
                    cosmetics: Character3dCosmetics.fromShopIds(
                      avatarId: rewards.equippedAvatar,
                      frameId: rewards.equippedFrame,
                    ),
                    glowColor: equippedColor ?? colors.primary,
                    celebrateTick: _celebrateTick,
                    onEdit: () => context.push(RouteNames.editProfile),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ProfileStatsGrid(
                    streak: currentStreak,
                    coins: wallet?.coins ?? 0,
                    gems: wallet?.gems ?? 0,
                    level: profile.level,
                    onWallet: () => context.push(RouteNames.wallet),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        StreakWeekRow(currentStreak: currentStreak),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          currentStreak > 0
                              ? 'Play today to keep your streak alive'
                              : 'Play today to start your streak',
                          style: context.appTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AchievementsSection(items: badges),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _NavTile(
                          icon: Icons.storefront_rounded,
                          title: 'Shop',
                          color: colors.primary,
                          onTap: () => context.push(RouteNames.shop),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.ms),
                      Expanded(
                        child: _NavTile(
                          icon: Icons.auto_awesome,
                          title: 'Cosmetics',
                          color: colors.violet,
                          onTap: () => context.push(RouteNames.cosmetics),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SettingsCard(email: user.email),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: colors.error,
                      ),
                      label: Text(
                        'Logout',
                        style: context.appTextStyles.labelLarge.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.ms),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: context.appTextStyles.labelLarge),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// The account and the sound switch, in one quiet card.
class _SettingsCard extends ConsumerWidget {
  final String email;

  const _SettingsCard({required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final soundSettings = ref.watch(soundSettingsControllerProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: styles.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.bodyMedium,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          // A plain row (not a list tile): a list tile inside a coloured card
          // hides its own ink and trips a debug check.
          Row(
            children: [
              Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sound Effects', style: styles.bodyMedium),
                    Text(
                      'Game audio and interactive feedback',
                      style: styles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: soundSettings.sfxEnabled,
                activeThumbColor: colors.primary,
                onChanged: (val) {
                  ref
                      .read(soundSettingsControllerProvider.notifier)
                      .toggleSfx(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
