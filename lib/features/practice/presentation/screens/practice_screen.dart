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
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../questions/domain/entities/question.dart';

const _practiceModes = [
  QuestionType.mcq,
  QuestionType.matchTheFollowing,
  QuestionType.suddenDeath,
  QuestionType.sortItRight,
];

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            96,
          ),
          children: [
            Text(
              'Choose quiz type',
              style: context.appTextStyles.displayMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick one game mode, then choose a subject, chapter, and topic.',
              style: context.appTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final mode in _practiceModes) ...[
              _QuizModeCard(
                mode: mode,
                onTap: () => context.push(RouteNames.practiceTypePath(mode)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class PracticeSubjectSelectionScreen extends ConsumerWidget {
  final QuestionType quizType;

  const PracticeSubjectSelectionScreen({super.key, required this.quizType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);

    return GameScaffold(
      appBar: AppBar(title: Text(quizType.label)),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load subjects.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) => _SelectionList<LearningPath>(
            title: 'Choose subject',
            subtitle: 'Your quiz will only use ${quizType.label} questions.',
            items: paths,
            emptyMessage: 'No subjects available yet.',
            itemBuilder: (context, path) => _SelectionCard(
              title: path.title,
              subtitle: '${path.topicCount} topics',
              icon: Icons.school_outlined,
              onTap: () => context.push(
                RouteNames.practiceSubjectPath(quizType, path.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeChapterSelectionScreen extends ConsumerWidget {
  final QuestionType quizType;
  final String subjectId;

  const PracticeChapterSelectionScreen({
    super.key,
    required this.quizType,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));

    return GameScaffold(
      appBar: AppBar(title: const Text('Choose chapter')),
      body: SafeArea(
        child: chaptersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load chapters.',
            onRetry: () => ref.invalidate(chaptersProvider(subjectId)),
          ),
          data: (chapters) => _SelectionList(
            title: 'Choose chapter',
            subtitle: quizType.label,
            items: chapters,
            emptyMessage: 'No chapters available yet.',
            itemBuilder: (context, chapter) => _SelectionCard(
              title: chapter.title,
              subtitle: '${chapter.topicCount} topics',
              icon: Icons.menu_book_outlined,
              onTap: () => context.push(
                RouteNames.practiceChapterPath(quizType, subjectId, chapter.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeTopicSelectionScreen extends ConsumerWidget {
  final QuestionType quizType;
  final String subjectId;
  final String chapterId;

  const PracticeTopicSelectionScreen({
    super.key,
    required this.quizType,
    required this.subjectId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(title: const Text('Choose topic')),
      body: SafeArea(
        child: topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load topics.',
            onRetry: () => ref.invalidate(topicsProvider(chapterId)),
          ),
          data: (topics) => _SelectionList<Topic>(
            title: 'Choose topic',
            subtitle: 'Start a ${quizType.label} session.',
            items: topics,
            emptyMessage: 'No topics available yet.',
            itemBuilder: (context, topic) => _SelectionCard(
              title: topic.title,
              subtitle: topic.isCompleted ? 'Completed' : 'Not completed',
              icon: Icons.topic_outlined,
              onTap: () => context.push(
                RouteNames.practiceTopicPath(
                  quizType,
                  subjectId,
                  chapterId,
                  topic.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeStartScreen extends ConsumerWidget {
  final QuestionType quizType;
  final String subjectId;
  final String chapterId;
  final String topicId;

  const PracticeStartScreen({
    super.key,
    required this.quizType,
    required this.subjectId,
    required this.chapterId,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(title: const Text('Start quiz')),
      body: SafeArea(
        child: topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this topic.',
            onRetry: () => ref.invalidate(topicsProvider(chapterId)),
          ),
          data: (topics) {
            final topic = _findTopic(topics, topicId);
            if (topic == null) {
              return const _MessageState(message: 'Topic not found.');
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                AppCard(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: context.appTextStyles.displayMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        quizType.label,
                        style: context.appTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Start Quiz',
                        leadingIcon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () => context.push(
                          RouteNames.quizPath(
                            topic.id,
                            quizType,
                            subjectId: subjectId,
                            chapterId: chapterId,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TopicPracticeModeSelectionScreen extends ConsumerWidget {
  final String chapterId;
  final String topicId;

  const TopicPracticeModeSelectionScreen({
    super.key,
    required this.chapterId,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterAsync = ref.watch(chapterByIdProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(title: const Text('Choose quiz type')),
      body: SafeArea(
        child: chapterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this chapter.',
            onRetry: () => ref.invalidate(chapterByIdProvider(chapterId)),
          ),
          data: (chapter) {
            if (chapter == null) {
              return const _MessageState(message: 'Chapter not found.');
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(
                  'Practice this topic',
                  style: context.appTextStyles.displayMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose one quiz type. The topic is already selected.',
                  style: context.appTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final mode in _practiceModes) ...[
                  _QuizModeCard(
                    mode: mode,
                    onTap: () => context.push(
                      RouteNames.quizPath(
                        topicId,
                        mode,
                        subjectId: chapter.learningPathId,
                        chapterId: chapterId,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuizModeCard extends StatelessWidget {
  final QuestionType mode;
  final VoidCallback onTap;

  const _QuizModeCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = _modeColor(colors, mode);

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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(_modeIcon(mode), color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _modeDescription(mode),
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

class _SelectionList<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<T> items;
  final String emptyMessage;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const _SelectionList({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _MessageState(message: emptyMessage);

    return ListView.separated(
      padding: AppSpacing.paddingMd,
      itemCount: items.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.appTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: context.appTextStyles.bodyMedium),
              ],
            ),
          );
        }
        return itemBuilder(context, items[index - 1]);
      },
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

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
            Icon(icon, color: colors.primary, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: context.appTextStyles.bodyMedium),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.appTextStyles.bodyLarge,
        ),
      ),
    );
  }
}

Topic? _findTopic(List<Topic> topics, String topicId) {
  for (final topic in topics) {
    if (topic.id == topicId) return topic;
  }
  return null;
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

String _modeDescription(QuestionType mode) {
  return switch (mode) {
    QuestionType.mcq => 'Standard answer-selection challenge.',
    QuestionType.matchTheFollowing => 'Pair concepts with their answers.',
    QuestionType.suddenDeath =>
      'Keep going until one wrong answer ends the run.',
    QuestionType.sortItRight => 'Arrange items into the correct order.',
  };
}
