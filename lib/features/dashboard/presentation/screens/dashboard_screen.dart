import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../chapters/presentation/widgets/chapter_card.dart';
import '../../../daily_missions/presentation/widgets/daily_missions_tile.dart';
import '../../../daily_rewards/presentation/widgets/daily_reward_tile.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../streaks/presentation/widgets/streak_tile.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final selectedPathId = ref.watch(selectedLearningPathControllerProvider).valueOrNull;
    final pathsAsync = ref.watch(learningPathsProvider);
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront),
            tooltip: 'Shop',
            onPressed: () => context.push(RouteNames.shop),
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => context.push(RouteNames.leaderboard),
          ),
          const ThemeModeMenu(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.paddingMd,
          children: [
            _CompactProfileHeader(
              displayName: user?.displayName ?? '',
              avatarId: profile?.avatarId ?? 'default',
              coins: wallet?.coins ?? 0,
              gems: wallet?.gems ?? 0,
              onTap: () => context.push(RouteNames.profile),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Current Learning Path', style: context.appTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            pathsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Text('Could not load your learning path.', style: context.appTextStyles.bodyMedium),
              data: (paths) {
                if (selectedPathId == null) {
                  return Text('No learning path selected.', style: context.appTextStyles.bodyMedium);
                }
                LearningPath? path;
                for (final candidate in paths) {
                  if (candidate.id == selectedPathId) {
                    path = candidate;
                    break;
                  }
                }
                if (path == null) {
                  return Text('Learning path not found.', style: context.appTextStyles.bodyMedium);
                }

                return AppPressable(
                  onTap: () => context.push(RouteNames.learningPath),
                  borderRadius: AppDimensions.radiusMd,
                  child: Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: AppDimensions.radiusMd,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(path.title, style: context.appTextStyles.titleMedium),
                              const SizedBox(height: AppSpacing.xs),
                              Text('${path.topicCount} topics', style: context.appTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: colors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chapters', style: context.appTextStyles.titleMedium),
                TextButton(
                  onPressed: () => context.push(RouteNames.learningPath),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (selectedPathId != null)
              Consumer(
                builder: (context, ref, _) {
                  final chaptersAsync = ref.watch(chaptersProvider(selectedPathId));

                  return chaptersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        Text('Could not load chapters.', style: context.appTextStyles.bodyMedium),
                    data: (chapters) {
                      if (chapters.isEmpty) {
                        return Text('No chapters available yet.', style: context.appTextStyles.bodyMedium);
                      }
                      final preview = chapters.take(3).toList();
                      return Column(
                        children: [
                          for (final chapter in preview)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ChapterCard(
                                chapter: chapter,
                                onTap: () => context.push(RouteNames.chapterPath(chapter.id)),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: const [
                StreakTile(),
                SizedBox(width: AppSpacing.sm),
                DailyMissionsTile(),
                SizedBox(width: AppSpacing.sm),
                DailyRewardTile(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactProfileHeader extends StatelessWidget {
  final String displayName;
  final String avatarId;
  final int coins;
  final int gems;
  final VoidCallback onTap;

  const _CompactProfileHeader({
    required this.displayName,
    required this.avatarId,
    required this.coins,
    required this.gems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      key: const Key('compact_profile_header'),
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.surfaceElevated,
              child: Icon(AvatarCatalog.iconFor(avatarId), color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                displayName,
                style: context.appTextStyles.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.monetization_on, color: AppColors.coinGold, size: 18),
            const SizedBox(width: AppSpacing.xs),
            AnimatedCountText(value: coins, style: context.appTextStyles.labelLarge),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.diamond, color: AppColors.gemCyan, size: 18),
            const SizedBox(width: AppSpacing.xs),
            AnimatedCountText(value: gems, style: context.appTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }
}
