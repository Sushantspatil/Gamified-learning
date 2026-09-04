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
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../questions/presentation/providers/question_providers.dart';

const _practiceModes = [
  QuestionType.mcq,
  QuestionType.matchTheFollowing,
  QuestionType.sortItRight,
  QuestionType.suddenDeath,
];

class PlaySetupScreen extends ConsumerStatefulWidget {
  final String subjectId;

  const PlaySetupScreen({super.key, required this.subjectId});

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  String? _selectedChapterId;
  String? _selectedTopicId;
  QuestionType? _selectedMode;

  void _selectChapter(String? chapterId) {
    if (chapterId == _selectedChapterId) return;
    setState(() {
      _selectedChapterId = chapterId;
      _selectedTopicId = null;
      _selectedMode = null;
    });
  }

  void _selectTopic(String? topicId) {
    if (topicId == _selectedTopicId) return;
    setState(() {
      _selectedTopicId = topicId;
      _selectedMode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final chaptersAsync = ref.watch(chaptersProvider(widget.subjectId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Play'),
        actions: const [ThemeModeMenu()],
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.paddingMd,
        child: AppButton(
          label: 'Start game',
          leadingIcon: const Icon(Icons.play_arrow_rounded),
          onPressed: _canStart
              ? () => context.push(
                  RouteNames.quizPath(
                    _selectedTopicId!,
                    _selectedMode!,
                    subjectId: widget.subjectId,
                    chapterId: _selectedChapterId,
                  ),
                )
              : null,
        ),
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this subject.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) {
            final subject = _findSubject(paths, widget.subjectId);
            if (subject == null) {
              return const _MessageState(message: 'Subject not found.');
            }

            return chaptersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                message: 'Could not load chapters.',
                onRetry: () =>
                    ref.invalidate(chaptersProvider(widget.subjectId)),
              ),
              data: (chapters) {
                if (chapters.isEmpty) {
                  return const _MessageState(
                    message: 'No playable questions are available yet.',
                  );
                }

                final selectedChapter = _findChapter(
                  chapters,
                  _selectedChapterId,
                );
                final topicsAsync = selectedChapter == null
                    ? null
                    : ref.watch(topicsProvider(selectedChapter.id));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    112,
                  ),
                  children: [
                    Text(
                      'Play ${subject.title}',
                      style: context.appTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Choose what to practice and how to play.',
                      style: context.appTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SetupSection(
                      title: 'What do you want to practice?',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ChapterDropdown(
                            chapters: chapters,
                            selectedChapterId: _selectedChapterId,
                            onChanged: _selectChapter,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _TopicPicker(
                            topicsAsync: topicsAsync,
                            selectedChapter: selectedChapter,
                            selectedTopicId: _selectedTopicId,
                            onChanged: _selectTopic,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _GameModePicker(
                      selectedTopicId: _selectedTopicId,
                      selectedMode: _selectedMode,
                      onChanged: (mode) => setState(() {
                        _selectedMode = mode;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool get _canStart =>
      _selectedChapterId != null &&
      _selectedTopicId != null &&
      _selectedMode != null;
}

class _SetupSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SetupSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.appTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ChapterDropdown extends StatelessWidget {
  final List<Chapter> chapters;
  final String? selectedChapterId;
  final ValueChanged<String?> onChanged;

  const _ChapterDropdown({
    required this.chapters,
    required this.selectedChapterId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('play-chapter-dropdown'),
      initialValue: selectedChapterId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Chapter'),
      items: [
        for (final chapter in chapters)
          DropdownMenuItem(
            value: chapter.id,
            child: Text(
              chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _TopicPicker extends StatelessWidget {
  final AsyncValue<List<Topic>>? topicsAsync;
  final Chapter? selectedChapter;
  final String? selectedTopicId;
  final ValueChanged<String?> onChanged;

  const _TopicPicker({
    required this.topicsAsync,
    required this.selectedChapter,
    required this.selectedTopicId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedChapter = this.selectedChapter;
    final topicsAsync = this.topicsAsync;
    if (selectedChapter == null || topicsAsync == null) {
      return DropdownButtonFormField<String>(
        key: const Key('play-topic-dropdown'),
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Topic'),
        items: const [],
        hint: const Text('Select a chapter first'),
        onChanged: null,
      );
    }

    return topicsAsync.when(
      loading: () => const AppCard(
        variant: AppCardVariant.outlined,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Loading topics'),
          ],
        ),
      ),
      error: (error, stackTrace) => Text(
        'Could not load topics.',
        style: context.appTextStyles.bodyMedium,
      ),
      data: (topics) {
        if (topics.isEmpty) {
          return Text(
            'No playable questions are available for this topic yet.',
            style: context.appTextStyles.bodyMedium,
          );
        }

        return DropdownButtonFormField<String>(
          key: const Key('play-topic-dropdown'),
          initialValue: selectedTopicId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Topic'),
          items: [
            for (final topic in topics)
              DropdownMenuItem(
                value: topic.id,
                child: Text(
                  topic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _GameModePicker extends ConsumerWidget {
  final String? selectedTopicId;
  final QuestionType? selectedMode;
  final ValueChanged<QuestionType> onChanged;

  const _GameModePicker({
    required this.selectedTopicId,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicId = selectedTopicId;
    final questionsAsync = topicId == null
        ? const AsyncValue<List<Question>>.data([])
        : ref.watch(questionsForTopicProvider(topicId));

    return _SetupSection(
      title: 'Choose game mode',
      child: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(
          'No playable questions are available for this topic yet.',
          style: context.appTextStyles.bodyMedium,
        ),
        data: (questions) {
          final availability = {
            for (final mode in _practiceModes)
              mode: _modeAvailability(mode, questions),
          };

          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.22,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final mode in _practiceModes)
                _SelectableQuizModeCard(
                  mode: mode,
                  isSelected: mode == selectedMode,
                  availability: availability[mode]!,
                  onTap: () => onChanged(mode),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectableQuizModeCard extends StatelessWidget {
  final QuestionType mode;
  final bool isSelected;
  final _ModeAvailability availability;
  final VoidCallback onTap;

  const _SelectableQuizModeCard({
    required this.mode,
    required this.isSelected,
    required this.availability,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = _modeColor(colors, mode);
    final enabled = availability.isEnabled;

    return AppPressable(
      key: Key('play-mode-${mode.routeValue}'),
      onTap: enabled ? onTap : null,
      borderRadius: AppDimensions.radiusCard,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.14)
                : colors.cardBackground,
            borderRadius: AppDimensions.radiusCard,
            border: Border.all(
              color: isSelected
                  ? accent
                  : enabled
                  ? colors.border
                  : colors.borderStrong,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: AppSpacing.paddingMs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_modeIcon(mode), color: accent, size: 22),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle, color: accent, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  _modeShortName(mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.labelLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  availability.reason ?? _modeDescription(mode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

Topic? _findTopic(List<Topic> topics, String topicId) {
  for (final topic in topics) {
    if (topic.id == topicId) return topic;
  }
  return null;
}

LearningPath? _findSubject(List<LearningPath> paths, String subjectId) {
  for (final path in paths) {
    if (path.id == subjectId) return path;
  }
  return null;
}

Chapter? _findChapter(List<Chapter> chapters, String? chapterId) {
  if (chapterId == null) return null;
  for (final chapter in chapters) {
    if (chapter.id == chapterId) return chapter;
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
    QuestionType.mcq => 'Choose the correct answer.',
    QuestionType.matchTheFollowing => 'Connect the correct pairs.',
    QuestionType.suddenDeath => 'Answer correctly before time runs out.',
    QuestionType.sortItRight => 'Swipe answers into the right group.',
  };
}

String _modeShortName(QuestionType mode) {
  return switch (mode) {
    QuestionType.mcq => 'MCQ',
    QuestionType.matchTheFollowing => 'Match',
    QuestionType.sortItRight => 'Sort It Out',
    QuestionType.suddenDeath => 'Sudden Death',
  };
}

_ModeAvailability _modeAvailability(
  QuestionType mode,
  List<Question> questions,
) {
  final hasTopic = questions.isNotEmpty;
  if (!hasTopic) {
    return const _ModeAvailability(
      isEnabled: false,
      reason: 'Select a topic first',
    );
  }

  final matching = questions.where((question) => question.type == mode);
  final canRun = switch (mode) {
    QuestionType.mcq => matching.any(
      (question) => question is McqQuestion && question.options.length >= 2,
    ),
    QuestionType.matchTheFollowing => matching.any(
      (question) =>
          question is MatchTheFollowingQuestion && question.pairs.length >= 2,
    ),
    QuestionType.sortItRight => matching.any(
      (question) =>
          question is SortItRightQuestion && question.itemsInOrder.length >= 2,
    ),
    QuestionType.suddenDeath => matching.any(
      (question) =>
          question is SuddenDeathQuestion && question.options.length >= 2,
    ),
  };

  if (canRun) return const _ModeAvailability(isEnabled: true);

  return _ModeAvailability(
    isEnabled: false,
    reason: switch (mode) {
      QuestionType.mcq => 'No MCQ questions yet',
      QuestionType.matchTheFollowing => 'Not enough matching pairs yet',
      QuestionType.sortItRight => 'Not enough sortable items yet',
      QuestionType.suddenDeath => 'No timed questions yet',
    },
  );
}

class _ModeAvailability {
  final bool isEnabled;
  final String? reason;

  const _ModeAvailability({required this.isEnabled, this.reason});
}
