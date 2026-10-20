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
import '../../../../core/errors/app_exception.dart';
import '../../../chapters/domain/entities/chapter.dart';
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../quiz/data/datasources/remote/quiz_remote_datasource.dart';
import '../../../quiz/presentation/providers/quiz_providers.dart';
import '../../../quiz/presentation/providers/sudden_death_providers.dart';
import '../providers/practice_providers.dart';

const _practiceModes = practicePlayableModes;

class PlaySetupScreen extends ConsumerStatefulWidget {
  final String? initialSubjectId;
  final String? initialChapterId;
  final String? initialTopicId;
  final QuestionType? initialGameMode;

  const PlaySetupScreen({
    super.key,
    this.initialSubjectId,
    this.initialChapterId,
    this.initialTopicId,
    this.initialGameMode,
  });

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  late String? _selectedSubjectId;
  String? _selectedChapterId;
  String? _selectedTopicId;
  QuestionType? _selectedMode;
  bool _isStartingGame = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _selectedChapterId = widget.initialChapterId;
    _selectedTopicId = widget.initialTopicId;
    _selectedMode = widget.initialGameMode;
  }

  void _selectSubject(String? subjectId) {
    if (subjectId == _selectedSubjectId) return;
    setState(() {
      _selectedSubjectId = subjectId;
      _selectedChapterId = null;
      _selectedTopicId = null;
      _selectedMode = null;
    });
  }

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

  Future<void> _onStartGame() async {
    if (!_canStart || _isStartingGame) return;
    final topicId = _selectedTopicId!;
    final mode = _selectedMode!;
    final subjectId = _selectedSubjectId;
    final chapterId = _selectedChapterId;

    setState(() {
      _isStartingGame = true;
    });

    try {
      await _initializeGameSession(topicId, mode);

      if (!mounted) return;

      if (mode == QuestionType.suddenDeath) {
        context.push(
          RouteNames.suddenDeathPath(
            topicId,
            subjectId: subjectId,
            chapterId: chapterId,
          ),
        );
      } else {
        context.push(
          RouteNames.quizPath(
            topicId,
            mode,
            subjectId: subjectId,
            chapterId: chapterId,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMessage = _resolveUserFriendlyError(e, mode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingGame = false;
        });
      }
    }
  }

  Future<void> _initializeGameSession(String topicId, QuestionType mode) async {
    final quizDatasource = ref.read(quizDatasourceProvider);
    final suddenDeathDatasource = ref.read(suddenDeathDatasourceProvider);

    switch (mode) {
      case QuestionType.mcq:
        if (quizDatasource is QuizRemoteDatasource) {
          final sessionId = await quizDatasource.createSession(
            topicId: topicId,
            questionCount: 10,
            gameMode: mode.backendGameMode,
          );
          final questions = quizDatasource.activeSessionQuestions;
          if (sessionId.isEmpty || questions == null || questions.isEmpty) {
            throw const ValidationException(
              'No MCQ questions available for this topic yet.',
              'no-mcq-questions',
            );
          }
        }
      case QuestionType.sortItRight:
        if (quizDatasource is QuizRemoteDatasource) {
          final sessionId = await quizDatasource.createSession(
            topicId: topicId,
            questionCount: 10,
            gameMode: mode.backendGameMode,
          );
          final cards = quizDatasource.activeSortItOutCards;
          if (sessionId.isEmpty || cards == null || cards.isEmpty) {
            throw const ValidationException(
              'Sort It Out is not available for this topic yet.',
              'no-sort-cards',
            );
          }
        }
      case QuestionType.matchTheFollowing:
        if (quizDatasource is QuizRemoteDatasource) {
          final sessionId = await quizDatasource.createSession(
            topicId: topicId,
            questionCount: 3,
            gameMode: mode.backendGameMode,
          );
          final boards = quizDatasource.activeMatchBoards;
          if (sessionId.isEmpty || boards == null || boards.isEmpty) {
            throw const ValidationException(
              'Match the Following is not available for this topic yet.',
              'no-match-boards',
            );
          }
        }
      case QuestionType.suddenDeath:
        final sessionId = await suddenDeathDatasource.createSession(
          topicId: topicId,
          questionCount: 10,
          gameMode: mode.backendGameMode,
        );
        if (sessionId.isEmpty) {
          throw const ValidationException(
            'Sudden Death is not available for this topic yet.',
            'no-sudden-death-questions',
          );
        }
    }
  }

  String _resolveUserFriendlyError(Object error, QuestionType mode) {
    if (error is AuthException) {
      return 'Your session has expired. Please log in again.';
    }
    if (error is NetworkException) {
      return 'Network unavailable. Please check your internet connection and try again.';
    }
    final modeLabel = _modeShortName(mode);
    if (error is NotFoundException ||
        (error is AppException &&
            (error.message.toLowerCase().contains('not found') ||
                error.message.toLowerCase().contains('no questions') ||
                error.message.toLowerCase().contains('no sort_it_out') ||
                error.message.toLowerCase().contains('no match_the_following')))) {
      return '$modeLabel is not available for this topic yet.';
    }
    if (error is ValidationException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('active session already exists')) {
        return 'An active game session already exists. Please finish or abandon it first.';
      }
      if (msg.contains('not available') ||
          msg.contains('no questions') ||
          msg.contains('no sort') ||
          msg.contains('no match')) {
        return '$modeLabel is not available for this topic yet.';
      }
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }
    return 'Could not start game. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final selectedSubjectId = _selectedSubjectId;
    final chaptersAsync = selectedSubjectId == null
        ? null
        : ref.watch(chaptersProvider(selectedSubjectId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Play'),
        actions: const [ThemeModeMenu()],
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.paddingMd,
        child: AppButton(
          label: _isStartingGame ? 'Starting game...' : 'Start game',
          leadingIcon: _isStartingGame
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          onPressed: _canStart ? _onStartGame : null,
        ),
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load subjects.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) {
            final visiblePaths = paths;
            if (visiblePaths.isEmpty) {
              return const _MessageState(
                message: 'No playable subjects are available yet.',
              );
            }

            final subject = selectedSubjectId == null
                ? null
                : _findSubject(visiblePaths, selectedSubjectId);
            if (selectedSubjectId != null && subject == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _selectSubject(null);
              });
            }

            if (chaptersAsync == null) {
              return _SetupContent(
                paths: visiblePaths,
                selectedSubjectId: _selectedSubjectId,
                selectedChapterId: _selectedChapterId,
                selectedTopicId: _selectedTopicId,
                selectedMode: _selectedMode,
                chapters: const [],
                topicsAsync: null,
                selectedChapter: null,
                onSubjectChanged: _selectSubject,
                onChapterChanged: _selectChapter,
                onTopicChanged: _selectTopic,
                onModeChanged: (mode) => setState(() {
                  _selectedMode = mode;
                }),
              );
            }

            return chaptersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                message: 'Could not load chapters.',
                onRetry: () =>
                    ref.invalidate(chaptersProvider(selectedSubjectId!)),
              ),
              data: (chapters) {
                final selectedChapter = _findChapter(
                  chapters,
                  _selectedChapterId,
                );
                final topicsAsync = selectedChapter == null
                    ? null
                    : ref.watch(topicsProvider(selectedChapter.id));

                return _SetupContent(
                  paths: visiblePaths,
                  selectedSubjectId: _selectedSubjectId,
                  selectedChapterId: _selectedChapterId,
                  selectedTopicId: _selectedTopicId,
                  selectedMode: _selectedMode,
                  subject: subject,
                  chapters: chapters,
                  topicsAsync: topicsAsync,
                  selectedChapter: selectedChapter,
                  onSubjectChanged: _selectSubject,
                  onChapterChanged: _selectChapter,
                  onTopicChanged: _selectTopic,
                  onModeChanged: (mode) => setState(() {
                    _selectedMode = mode;
                  }),
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool get _canStart {
    if (_selectedSubjectId == null ||
        _selectedChapterId == null ||
        _selectedTopicId == null ||
        _selectedMode == null ||
        _isStartingGame) {
      return false;
    }
    final availability =
        ref.read(gameModeAvailabilityProvider(_selectedTopicId));
    return availability[_selectedMode]?.isEnabled ?? false;
  }
}

class _SetupContent extends StatelessWidget {
  final List<LearningPath> paths;
  final String? selectedSubjectId;
  final String? selectedChapterId;
  final String? selectedTopicId;
  final QuestionType? selectedMode;
  final LearningPath? subject;
  final List<Chapter> chapters;
  final AsyncValue<List<Topic>>? topicsAsync;
  final Chapter? selectedChapter;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onChapterChanged;
  final ValueChanged<String?> onTopicChanged;
  final ValueChanged<QuestionType> onModeChanged;

  const _SetupContent({
    required this.paths,
    required this.selectedSubjectId,
    required this.selectedChapterId,
    required this.selectedTopicId,
    required this.selectedMode,
    required this.chapters,
    required this.topicsAsync,
    required this.selectedChapter,
    required this.onSubjectChanged,
    required this.onChapterChanged,
    required this.onTopicChanged,
    required this.onModeChanged,
    this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final title = subject == null ? 'Play' : 'Play ${subject!.title}';
    final visibleChapterId =
        chapters.any((chapter) => chapter.id == selectedChapterId)
        ? selectedChapterId
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        112,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.appTextStyles.displayMedium),
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
                _SubjectDropdown(
                  paths: paths,
                  selectedSubjectId: selectedSubjectId,
                  onChanged: onSubjectChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                _ChapterDropdown(
                  chapters: chapters,
                  selectedSubjectId: selectedSubjectId,
                  selectedChapterId: visibleChapterId,
                  onChanged: onChapterChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                _TopicPicker(
                  topicsAsync: topicsAsync,
                  selectedChapter: selectedChapter,
                  selectedTopicId: selectedTopicId,
                  onChanged: onTopicChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _GameModePicker(
            selectedTopicId: selectedTopicId,
            selectedMode: selectedMode,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
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

class _SubjectDropdown extends StatelessWidget {
  final List<LearningPath> paths;
  final String? selectedSubjectId;
  final ValueChanged<String?> onChanged;

  const _SubjectDropdown({
    required this.paths,
    required this.selectedSubjectId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('play-subject-dropdown'),
      initialValue: selectedSubjectId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Subject'),
      items: [
        for (final path in paths)
          DropdownMenuItem(
            value: path.id,
            child: Text(
              path.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ChapterDropdown extends StatelessWidget {
  final List<Chapter> chapters;
  final String? selectedSubjectId;
  final String? selectedChapterId;
  final ValueChanged<String?> onChanged;

  const _ChapterDropdown({
    required this.chapters,
    required this.selectedSubjectId,
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
      hint: selectedSubjectId == null
          ? const Text('Select a subject first')
          : null,
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
      onChanged: selectedSubjectId == null || chapters.isEmpty
          ? null
          : onChanged,
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
          initialValue: topics.any((topic) => topic.id == selectedTopicId)
              ? selectedTopicId
              : null,
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
    // Mode availability is evaluated directly based on topic capability
    // rather than relying on the generic MCQ question endpoint.
    final availability =
        ref.watch(gameModeAvailabilityProvider(selectedTopicId));

    return _SetupSection(
      title: 'Choose game mode',
      child: GridView.count(
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
      ),
    );
  }
}

class _SelectableQuizModeCard extends StatelessWidget {
  final QuestionType mode;
  final bool isSelected;
  final GameModeAvailability availability;
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
