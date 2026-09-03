import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../chapters/domain/entities/chapter.dart';
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../domain/entities/learning_path.dart';
import '../providers/learning_path_providers.dart';

class SubjectDetailScreen extends ConsumerWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Level map'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this subject.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) {
            final subject = _findSubject(paths, subjectId);
            if (subject == null) {
              return const _MessageState(message: 'Subject not found.');
            }

            return chaptersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                message: 'Could not load chapters.',
                onRetry: () => ref.invalidate(chaptersProvider(subjectId)),
              ),
              data: (chapters) {
                if (chapters.isEmpty) {
                  return const _MessageState(
                    message: 'No levels available yet.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    96,
                  ),
                  children: [
                    _SubjectMapHeader(subject: subject),
                    const SizedBox(height: AppSpacing.lg),
                    for (var index = 0; index < chapters.length; index++) ...[
                      _WorldSection(
                        chapter: chapters[index],
                        worldIndex: index,
                        firstLevelNumber: _firstLevelNumber(chapters, index),
                      ),
                      if (index != chapters.length - 1)
                        const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SubjectMapHeader extends ConsumerWidget {
  final LearningPath subject;

  const _SubjectMapHeader({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.themeColors;
    final wallet = ref.watch(walletControllerProvider).valueOrNull;
    final streak = ref.watch(streakControllerProvider).valueOrNull;
    final completed = (subject.topicCount * 0.34).round();
    final progress = subject.topicCount == 0
        ? 0.0
        : completed / subject.topicCount;

    return AppCard(
      variant: AppCardVariant.tinted,
      tintColor: colors.primary,
      borderRadius: AppDimensions.radiusLg,
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.title,
                      style: context.appTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Chapters are worlds. Topics are levels.',
                      style: context.appTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _WalletChip(
                icon: Icons.monetization_on_rounded,
                value: wallet?.coins ?? 0,
                color: AppColors.coinGold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppDimensions.radiusCircular,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              color: colors.primary,
              backgroundColor: colors.primary.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricPill(
                icon: Icons.auto_graph_rounded,
                label: 'Level ${completed + 1}',
                color: colors.primary,
              ),
              _MetricPill(
                icon: Icons.local_fire_department_rounded,
                label: '${streak?.currentStreak ?? 0} day streak',
                color: AppColors.streakFire,
              ),
              _MetricPill(
                icon: Icons.star_rounded,
                label: '${completed * 120} XP',
                color: colors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorldSection extends ConsumerWidget {
  final Chapter chapter;
  final int worldIndex;
  final int firstLevelNumber;

  const _WorldSection({
    required this.chapter,
    required this.worldIndex,
    required this.firstLevelNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(chapter.id));
    final colors = context.themeColors;
    final worldColor = _worldColor(colors, worldIndex);

    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: worldColor.withValues(alpha: 0.12),
                  borderRadius: AppDimensions.radiusMd,
                ),
                child: Text(
                  '${worldIndex + 1}',
                  style: context.appTextStyles.titleMedium.copyWith(
                    color: worldColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'World ${worldIndex + 1}',
                      style: context.appTextStyles.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      chapter.title,
                      style: context.appTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.push(RouteNames.chapterPath(chapter.id)),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Guide'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          topicsAsync.when(
            loading: () => const Padding(
              padding: AppSpacing.paddingMd,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => _InlineError(
              message: 'Could not load levels.',
              onRetry: () => ref.invalidate(topicsProvider(chapter.id)),
            ),
            data: (topics) {
              if (topics.isEmpty) {
                return const Text('No levels available yet.');
              }

              return Column(
                children: [
                  for (var index = 0; index < topics.length; index++)
                    _LevelNode(
                      topic: topics[index],
                      chapter: chapter,
                      levelNumber: firstLevelNumber + index,
                      mode: _modeForLevel(firstLevelNumber + index),
                      status: _statusFor(index),
                      isLast: index == topics.length - 1,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChapterChallengeNode(chapter: chapter),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  final Topic topic;
  final Chapter chapter;
  final int levelNumber;
  final QuestionType mode;
  final _LevelStatus status;
  final bool isLast;

  const _LevelNode({
    required this.topic,
    required this.chapter,
    required this.levelNumber,
    required this.mode,
    required this.status,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = _modeColor(colors, mode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            children: [
              _LevelMarker(status: status, color: accent),
              if (!isLast)
                Container(
                  width: 3,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: AppDimensions.radiusCircular,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
            child: AppPressable(
              onTap: () => _showLevelSheet(context),
              borderRadius: AppDimensions.radiusMd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: AppDimensions.radiusMd,
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level $levelNumber',
                              style: context.appTextStyles.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              topic.title,
                              style: context.appTextStyles.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              mode.label,
                              style: context.appTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(_modeIcon(mode), color: accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLevelSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _LevelStartSheet(
        topic: topic,
        chapter: chapter,
        levelNumber: levelNumber,
        mode: mode,
      ),
    );
  }
}

class _LevelStartSheet extends StatelessWidget {
  final Topic topic;
  final Chapter chapter;
  final int levelNumber;
  final QuestionType mode;

  const _LevelStartSheet({
    required this.topic,
    required this.chapter,
    required this.levelNumber,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Level $levelNumber', style: context.appTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(topic.title, style: context.appTextStyles.displayMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(chapter.title, style: context.appTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MetricPill(
                  icon: Icons.quiz_outlined,
                  label: '10 questions',
                  color: colors.primary,
                ),
                _MetricPill(
                  icon: Icons.star_rounded,
                  label: '120 XP',
                  color: colors.violet,
                ),
                _MetricPill(
                  icon: Icons.monetization_on_rounded,
                  label: '+30 coins',
                  color: AppColors.coinGold,
                ),
                _MetricPill(
                  icon: _modeIcon(mode),
                  label: mode.label,
                  color: _modeColor(colors, mode),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Start level',
              leadingIcon: const Icon(Icons.play_arrow_rounded),
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  RouteNames.quizPath(
                    topic.id,
                    mode,
                    subjectId: chapter.learningPathId,
                    chapterId: chapter.id,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterChallengeNode extends StatelessWidget {
  final Chapter chapter;

  const _ChapterChallengeNode({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.10),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.coinGold),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter challenge',
                    style: context.appTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(chapter.title, style: context.appTextStyles.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _LevelMarker extends StatelessWidget {
  final _LevelStatus status;
  final Color color;

  const _LevelMarker({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final icon = switch (status) {
      _LevelStatus.completed => Icons.check_rounded,
      _LevelStatus.current => Icons.play_arrow_rounded,
      _LevelStatus.ready => Icons.star_rounded,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.48), width: 2),
      ),
      child: Icon(
        icon,
        color: status == _LevelStatus.ready ? colors.textSecondary : color,
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _WalletChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text('$value', style: context.appTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppDimensions.radiusCircular,
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: context.appTextStyles.labelLarge),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: context.appTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Retry',
          variant: AppButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

LearningPath? _findSubject(List<LearningPath> paths, String subjectId) {
  for (final path in paths) {
    if (path.id == subjectId) return path;
  }
  return null;
}

int _firstLevelNumber(List<Chapter> chapters, int chapterIndex) {
  var levelNumber = 1;
  for (var i = 0; i < chapterIndex; i++) {
    levelNumber += chapters[i].topicCount;
  }
  return levelNumber;
}

_LevelStatus _statusFor(int topicIndex) {
  if (topicIndex == 0) return _LevelStatus.current;
  if (topicIndex == 1) return _LevelStatus.completed;
  return _LevelStatus.ready;
}

QuestionType _modeForLevel(int levelNumber) {
  return switch (levelNumber % 5) {
    0 => QuestionType.suddenDeath,
    3 => QuestionType.matchTheFollowing,
    4 => QuestionType.sortItRight,
    _ => QuestionType.mcq,
  };
}

IconData _modeIcon(QuestionType mode) {
  return switch (mode) {
    QuestionType.mcq => Icons.quiz_outlined,
    QuestionType.matchTheFollowing => Icons.hub_outlined,
    QuestionType.suddenDeath => Icons.local_fire_department_outlined,
    QuestionType.sortItRight => Icons.sort_rounded,
  };
}

Color _modeColor(AppThemeColors colors, QuestionType mode) {
  return switch (mode) {
    QuestionType.mcq => colors.primary,
    QuestionType.matchTheFollowing => colors.secondary,
    QuestionType.suddenDeath => AppColors.streakFire,
    QuestionType.sortItRight => colors.violet,
  };
}

Color _worldColor(AppThemeColors colors, int index) {
  return switch (index % 4) {
    0 => colors.primary,
    1 => colors.secondary,
    2 => colors.violet,
    _ => AppColors.streakFire,
  };
}

enum _LevelStatus { completed, current, ready }

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: context.appTextStyles.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;

  const _MessageState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Text(message, style: context.appTextStyles.bodyLarge),
      ),
    );
  }
}
