import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_filter.dart';
import '../leaderboard_reset.dart';
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
                _UnsupportedScopeTab(
                  label: 'Friends',
                  icon: Icons.group_rounded,
                ),
                _UnsupportedScopeTab(
                  label: 'School',
                  icon: Icons.school_rounded,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlobalLeaderboardTab extends ConsumerStatefulWidget {
  const _GlobalLeaderboardTab();

  @override
  ConsumerState<_GlobalLeaderboardTab> createState() =>
      _GlobalLeaderboardTabState();
}

class _GlobalLeaderboardTabState extends ConsumerState<_GlobalLeaderboardTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      ref.read(filteredLeaderboardProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(filteredLeaderboardProvider);
    final activeFilter = ref.watch(leaderboardFilterProvider);

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
                  onPressed: () =>
                      ref.read(filteredLeaderboardProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          final entries = state.entries;
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(filteredLeaderboardProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.paddingMd,
                children: [
                  _LeaderboardHeader(
                    entries: entries,
                    filter: activeFilter,
                    currentUserRank: state.currentUserRank,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _UnsupportedScopeMessage(
                    message: 'No global ranking data available yet.',
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              ),
            );
          }

          // The top three stand on a podium; everyone else is in the list.
          final podium = [
            for (final e in entries)
              if (e.rank <= 3) e,
          ];
          final rest = [
            for (final e in entries)
              if (e.rank > 3) e,
          ];
          const headerCount = 2; // the header and the podium
          final showFooter = state.hasMore || state.isLoadingMore;
          LeaderboardEntry? me;
          for (final e in entries) {
            if (e.isCurrentUser) me = e;
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(filteredLeaderboardProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.paddingMd,
                    itemCount: headerCount + rest.length + (showFooter ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _LeaderboardHeader(
                            entries: entries,
                            filter: activeFilter,
                            currentUserRank: state.currentUserRank,
                          ),
                        );
                      }
                      if (index == 1) {
                        return podium.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: _Podium(entries: podium),
                              );
                      }
                      final listIndex = index - headerCount;
                      if (listIndex == rest.length) {
                        if (state.isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(filteredLeaderboardProvider.notifier)
                                  .loadMore(),
                              child: const Text('Load more'),
                            ),
                          ),
                        );
                      }
                      return LeaderboardTile(entry: rest[listIndex]);
                    },
                  ),
                ),
              ),
              if (me != null || state.currentUserRank != null)
                _YourPositionBar(
                  me: me,
                  rank: me?.rank ?? state.currentUserRank!,
                  entries: entries,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The board's title, its top score and your rank, when it starts again, and
/// the Filters button. The period (Daily, Weekly...) is chosen right below.
class _LeaderboardHeader extends ConsumerWidget {
  final List<LeaderboardEntry> entries;
  final LeaderboardFilter filter;
  final int? currentUserRank;

  const _LeaderboardHeader({
    required this.entries,
    required this.filter,
    required this.currentUserRank,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final topScore = entries.isEmpty ? 0 : entries.first.score;
    final reset = leaderboardResetIn(filter.timeRange, DateTime.now());
    final activeFilters =
        (filter.quizType != null ? 1 : 0) + (filter.subjectId != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.warning, AppColors.accentGold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.warning.withValues(alpha: 0.22),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: colors.textInverse,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${filter.timeRange.label} arena',
                    style: styles.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Top score: ${LeaderboardTile.formatPoints(topScore)} points',
                    style: styles.bodyMedium,
                  ),
                  if (currentUserRank != null)
                    Text(
                      'Your rank: #$currentUserRank',
                      style: styles.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            _FiltersButton(
              activeCount: activeFilters,
              onPressed: () => _openFilters(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _PeriodSwitcher(
          selected: filter.timeRange,
          onSelected: (range) =>
              ref.read(leaderboardFilterProvider.notifier).setTimeRange(range),
        ),
        if (reset != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: colors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Resets in ~${leaderboardResetLabel(reset)}',
                key: const Key('leaderboard_reset'),
                style: styles.labelSmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.themeColors.surface,
      builder: (context) => const _FilterSheet(),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const _FiltersButton({required this.activeCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Badge(
      isLabelVisible: activeCount > 0,
      label: Text('$activeCount'),
      backgroundColor: colors.primary,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Filters'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          side: BorderSide(
            color: activeCount > 0 ? colors.primary : colors.border,
          ),
        ),
      ),
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  final LeaderboardTimeRange selected;
  final ValueChanged<LeaderboardTimeRange> onSelected;

  const _PeriodSwitcher({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final range in LeaderboardTimeRange.values)
          _FilterChip(
            label: range.label,
            selected: selected == range,
            onSelected: () => onSelected(range),
          ),
      ],
    );
  }
}

/// The less-used choices (which game, which subject), kept out of the way.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(leaderboardFilterProvider);
    final pathsAsync = ref.watch(learningPathsProvider);
    final controller = ref.read(leaderboardFilterProvider.notifier);
    final styles = context.appTextStyles;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Show scores for', style: styles.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text('Game', style: styles.titleMedium),
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
            const SizedBox(height: AppSpacing.md),
            Text('Subject', style: styles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            pathsAsync.when(
              loading: () =>
                  Text('Loading subjects...', style: styles.bodyMedium),
              error: (error, stackTrace) =>
                  Text('Subject filter unavailable.', style: styles.bodyMedium),
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
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
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

/// The top three, first place in the middle and tallest.
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _Podium({required this.entries});

  LeaderboardEntry? _at(int rank) {
    for (final e in entries) {
      if (e.rank == rank) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final order = [_at(2), _at(1), _at(3)];
    return Row(
      key: const Key('leaderboard_podium'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: order[i] == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm),
                    child: _PodiumPlace(entry: order[i]!),
                  ),
          ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final LeaderboardEntry entry;

  const _PodiumPlace({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final first = entry.rank == 1;
    final color = switch (entry.rank) {
      1 => AppColors.accentGold,
      2 => colors.secondary,
      _ => colors.violet,
    };
    final radius = first ? 34.0 : 28.0;
    final pedestal = switch (entry.rank) {
      1 => 84.0,
      2 => 64.0,
      _ => 50.0,
    };
    final hasNetworkAvatar =
        entry.avatarUrl != null &&
        (entry.avatarUrl!.startsWith('http://') ||
            entry.avatarUrl!.startsWith('https://'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (first)
          Icon(Icons.workspace_premium_rounded, color: color, size: 26)
        else
          const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: entry.isCurrentUser ? colors.primary : color,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: colors.surfaceElevated,
            backgroundImage: hasNetworkAvatar
                ? NetworkImage(entry.avatarUrl!)
                : null,
            child: hasNetworkAvatar
                ? null
                : Icon(
                    AvatarCatalog.iconFor(
                      entry.avatarId.isNotEmpty ? entry.avatarId : 'user',
                    ),
                    size: radius * 0.9,
                    color: colors.primary,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          entry.isCurrentUser
              ? '${entry.displayName} (You)'
              : entry.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: styles.labelLarge,
        ),
        Text(
          '${LeaderboardTile.formatPoints(entry.score)} points',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: styles.labelSmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: pedestal,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusMd),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.45),
                color.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            '#${entry.rank}',
            style: styles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

/// Where you stand, always visible above the bottom bar, and how far you are
/// from the place above you.
class _YourPositionBar extends StatelessWidget {
  final LeaderboardEntry? me;
  final int rank;
  final List<LeaderboardEntry> entries;

  const _YourPositionBar({
    required this.me,
    required this.rank,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;

    String? detail;
    if (me != null) {
      if (rank <= 1) {
        detail = 'Top of the board. Keep it up!';
      } else {
        // The score of the player just above you, if they are on screen.
        LeaderboardEntry? above;
        for (final e in entries) {
          if (e.rank < rank && (above == null || e.rank > above.rank)) {
            above = e;
          }
        }
        if (above != null) {
          final gap = above.score - me!.score;
          detail = gap > 0
              ? '${LeaderboardTile.formatPoints(gap)} pts to reach ${ordinal(above.rank)}'
              : null;
        }
      }
    }

    return Container(
      key: const Key('your_position_bar'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.ms,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle_rounded, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("You're ${ordinal(rank)}", style: styles.labelLarge),
                if (detail != null)
                  Text(
                    detail,
                    style: styles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (me != null)
            Text(
              '${LeaderboardTile.formatPoints(me!.score)} pts',
              style: styles.labelLarge.copyWith(color: colors.primary),
            ),
        ],
      ),
    );
  }
}

class _UnsupportedScopeTab extends StatelessWidget {
  final String label;
  final IconData icon;

  const _UnsupportedScopeTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _UnsupportedScopeMessage(
      message: '$label leaderboard is coming soon.',
      icon: icon,
    );
  }
}

class _UnsupportedScopeMessage extends StatelessWidget {
  final String message;
  final IconData icon;

  const _UnsupportedScopeMessage({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
