import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_providers.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: GameScaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          actions: const [ThemeModeMenu()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Global'),
              Tab(text: 'Friends'),
              Tab(text: 'School'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GlobalLeaderboardTab(),
            _ComingSoonTab(label: 'Friends'),
            _ComingSoonTab(label: 'School'),
          ],
        ),
      ),
    );
  }
}

class _GlobalLeaderboardTab extends ConsumerWidget {
  const _GlobalLeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);

    return SafeArea(
      child: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load the leaderboard.',
                  style: context.appTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref.invalidate(globalLeaderboardProvider),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No leaderboard data yet.',
                style: context.appTextStyles.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _LeaderboardHero(entries: entries);
              return LeaderboardTile(entry: entries[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _LeaderboardHero({required this.entries});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final topScore = entries.isEmpty ? 0 : entries.first.xp;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        variant: AppCardVariant.tinted,
        tintColor: colors.warning,
        padding: AppSpacing.paddingLg,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.warning, AppColors.accentGold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.warning.withValues(alpha: 0.22),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: colors.textInverse,
                size: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly arena', style: context.appTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Top score: $topScore XP',
                    style: context.appTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.14),
                borderRadius: AppDimensions.radiusCircular,
              ),
              child: Text(
                'Live',
                style: context.appTextStyles.labelSmall.copyWith(
                  color: colors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final String label;

  const _ComingSoonTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label leaderboard is coming soon.',
        style: context.appTextStyles.bodyLarge,
      ),
    );
  }
}
