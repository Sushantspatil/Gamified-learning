import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../chapters/domain/entities/chapter.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../domain/entities/learning_path.dart';
import '../providers/learning_path_providers.dart';

class SubjectDetailScreen extends ConsumerWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Subject'),
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

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                96,
              ),
              children: [
                _SubjectHeader(subject: subject),
                const SizedBox(height: AppSpacing.lg),
                _ModeChoiceCard(
                  key: const Key('subject-learn-card'),
                  icon: Icons.menu_book_outlined,
                  title: 'Learn',
                  description: 'Study concepts and learning material',
                  accent: context.themeColors.primary,
                  onTap: () =>
                      context.push(RouteNames.subjectLearnPath(subject.id)),
                ),
                const SizedBox(height: AppSpacing.md),
                _ModeChoiceCard(
                  key: const Key('subject-play-card'),
                  icon: Icons.sports_esports_outlined,
                  title: 'Play',
                  description: 'Practice concepts through game modes',
                  accent: context.themeColors.secondary,
                  onTap: () =>
                      context.push(RouteNames.subjectPlayPath(subject.id)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SubjectLearnChaptersScreen extends ConsumerWidget {
  final String subjectId;

  const SubjectLearnChaptersScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Learn'),
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
                    message: 'No learning material available yet.',
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
                    Text(
                      'Learn ${subject.title}',
                      style: context.appTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Study chapters, concepts, and explanations.',
                      style: context.appTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ContinueLearningCard(subject: subject, chapters: chapters),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Chapters', style: context.appTextStyles.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    for (var index = 0; index < chapters.length; index++) ...[
                      _LearnChapterCard(
                        chapter: chapters[index],
                        number: index + 1,
                      ),
                      if (index != chapters.length - 1)
                        const SizedBox(height: AppSpacing.sm),
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

class _SubjectHeader extends StatelessWidget {
  final LearningPath subject;

  const _SubjectHeader({required this.subject});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final progress = subject.topicCount == 0 ? 0.0 : 0.62;

    return AppCard(
      variant: AppCardVariant.tinted,
      tintColor: colors.primary,
      borderRadius: AppDimensions.radiusLg,
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: AppDimensions.radiusMd,
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _difficultyLabel(subject.difficulty),
                      style: context.appTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overall progress',
                  style: context.appTextStyles.labelLarge,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppProgressBar(
            value: progress,
            height: 7,
            semanticLabel: '${subject.title} overall progress',
          ),
        ],
      ),
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _ModeChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        variant: AppCardVariant.tinted,
        tintColor: accent,
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: context.appTextStyles.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends ConsumerWidget {
  final LearningPath subject;
  final List<Chapter> chapters;

  const _ContinueLearningCard({required this.subject, required this.chapters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = chapters.first;
    final topicsAsync = ref.watch(topicsProvider(chapter.id));

    return topicsAsync.when(
      loading: () =>
          const AppCard(child: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => AppCard(
        child: Text(
          'Continue learning is unavailable.',
          style: context.appTextStyles.bodyMedium,
        ),
      ),
      data: (topics) {
        final topic = topics.isEmpty ? null : topics.first;
        if (topic == null) {
          return AppCard(
            child: Text(
              'No learning material available yet.',
              style: context.appTextStyles.bodyMedium,
            ),
          );
        }

        return AppPressable(
          onTap: () => context.push(RouteNames.topicPath(chapter.id, topic.id)),
          borderRadius: AppDimensions.radiusCard,
          child: AppCard(
            variant: AppCardVariant.tinted,
            tintColor: context.themeColors.primary,
            padding: AppSpacing.paddingMd,
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue learning',
                        style: context.appTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${chapter.title} - ${topic.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LearnChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int number;

  const _LearnChapterCard({required this.chapter, required this.number});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: () => context.push(RouteNames.chapterPath(chapter.id)),
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: Text(
                number.toString().padLeft(2, '0'),
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${chapter.topicCount} topics',
                    style: context.appTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMd,
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

LearningPath? _findSubject(List<LearningPath> paths, String subjectId) {
  for (final path in paths) {
    if (path.id == subjectId) return path;
  }
  return null;
}

String _difficultyLabel(LearningPathDifficulty difficulty) {
  return switch (difficulty) {
    LearningPathDifficulty.beginner => 'Class 11',
    LearningPathDifficulty.intermediate => 'Class 12',
    LearningPathDifficulty.advanced => 'Advanced',
  };
}
