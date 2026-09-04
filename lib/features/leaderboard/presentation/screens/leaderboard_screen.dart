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
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_filter.dart';
import '../providers/leaderboard_providers.dart';
import '../widgets/leaderboard_tile.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return GameScaffold(
            appBar: AppBar(
              title: const Text('Leaderboard'),
              actions: const [ThemeModeMenu()],
              bottom: TabBar(
                onTap: (index) {
                  final scope = switch (index) {
                    1 => LeaderboardScope.friends,
                    2 => LeaderboardScope.school,
                    _ => LeaderboardScope.global,
                  };
                  ref.read(leaderboardFilterProvider.notifier).setScope(scope);
                },
                tabs: const [
                  Tab(text: 'Global'),
                  Tab(text: 'Friends'),
                  Tab(text: 'School'),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _GlobalLeaderboardTab(),
                _UnsupportedScopeTab(label: 'Friends'),
                _UnsupportedScopeTab(label: 'School'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlobalLeaderboardTab extends ConsumerWidget {
  const _GlobalLeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(filteredLeaderboardProvider);

    return SafeArea(
      child: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: AppSpacing.paddingMd,
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
                  onPressed: () => ref.invalidate(filteredLeaderboardProvider),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return ListView(
              padding: AppSpacing.paddingMd,
              children: const [
                _LeaderboardFilters(),
                SizedBox(height: AppSpacing.md),
                _UnsupportedScopeMessage(
                  message: 'No global ranking data available yet.',
                ),
              ],
            );
          }

          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: entries.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _LeaderboardHero(entries: entries);
              if (index == 1) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _LeaderboardFilters(),
                );
              }
              return LeaderboardTile(entry: entries[index - 2]);
            },
          );
        },
      ),
    );
  }
}

class _LeaderboardFilters extends ConsumerWidget {
  const _LeaderboardFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(leaderboardFilterProvider);
    final pathsAsync = ref.watch(learningPathsProvider);
    final controller = ref.read(leaderboardFilterProvider.notifier);

    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: context.appTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _FilterWrap(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter.quizType == null,
                onSelected: () => controller.setQuizType(null),
              ),
              for (final mode in QuestionType.values)
                _FilterChip(
                  label: mode.label,
                  selected: filter.quizType == mode,
                  onSelected: () => controller.setQuizType(mode),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          pathsAsync.when(
            loading: () => Text(
              'Loading subjects...',
              style: context.appTextStyles.bodyMedium,
            ),
            error: (error, stackTrace) => Text(
              'Subject filter unavailable.',
              style: context.appTextStyles.bodyMedium,
            ),
            data: (paths) => _FilterWrap(
              children: [
                _FilterChip(
                  label: 'All subjects',
                  selected: filter.subjectId == null,
                  onSelected: () => controller.setSubject(null),
                ),
                for (final path in paths)
                  _FilterChip(
                    label: path.title,
                    selected: filter.subjectId == path.id,
                    onSelected: () => controller.setSubject(path.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilterWrap(
            children: [
              for (final range in LeaderboardTimeRange.values)
                _FilterChip(
                  label: range.label,
                  selected: filter.timeRange == range,
                  onSelected: () => controller.setTimeRange(range),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mock convention: Daily uses today, Weekly uses the last 7 days, Monthly uses the last 30 days, and All Time has no date limit when result timestamps are available.',
            style: context.appTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _FilterWrap extends StatelessWidget {
  final List<Widget> children;

  const _FilterWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: children,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary.withValues(alpha: 0.14),
      labelStyle: context.appTextStyles.labelSmall.copyWith(
        color: selected ? colors.primary : colors.textSecondary,
      ),
      side: BorderSide(color: selected ? colors.primary : colors.border),
    );
  }
}

class _UnsupportedScopeTab extends StatelessWidget {
  final String label;

  const _UnsupportedScopeTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return _UnsupportedScopeMessage(
      message: '$label leaderboard is coming soon.',
    );
  }
}

class _UnsupportedScopeMessage extends StatelessWidget {
  final String message;

  const _UnsupportedScopeMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.appTextStyles.bodyLarge,
        ),
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
