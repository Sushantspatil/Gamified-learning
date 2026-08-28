import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../providers/quiz_providers.dart';
import '../widgets/match_the_following_view.dart';
import '../widgets/mcq_question_view.dart';
import '../widgets/quiz_result_view.dart';
import '../widgets/sort_it_right_view.dart';
import '../widgets/sudden_death_question_view.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';

class QuizScreen extends ConsumerWidget {
  final String topicId;
  final QuestionType quizType;
  final String? subjectId;
  final String? chapterId;

  const QuizScreen({
    super.key,
    required this.topicId,
    required this.quizType,
    this.subjectId,
    this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = QuizSessionRequest(
      topicId: topicId,
      quizType: quizType,
      subjectId: subjectId,
      chapterId: chapterId,
    );
    final sessionAsync = ref.watch(quizControllerProvider(request));
    final currentQuestion = sessionAsync.valueOrNull?.currentQuestion;
    final isMatchQuestion = currentQuestion is MatchTheFollowingQuestion;
    final isSuddenDeathQuestion = currentQuestion is SuddenDeathQuestion;
    final isMcqQuiz = quizType == QuestionType.mcq;
    final isSortItOutQuiz = quizType == QuestionType.sortItRight;

    return GameScaffold(
      appBar:
          isMcqQuiz ||
              isSortItOutQuiz ||
              isMatchQuestion ||
              isSuddenDeathQuestion
          ? null
          : AppBar(
              title: Text(quizType.label),
              actions: const [ThemeModeMenu()],
            ),
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load this quiz.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () =>
                        ref.invalidate(quizControllerProvider(request)),
                  ),
                ],
              ),
            ),
          ),
          data: (session) {
            if (session.isSubmittingResult) {
              return const Center(child: CircularProgressIndicator());
            }

            if (session.result != null) {
              return QuizResultView(
                result: session.result!,
                rewardXp: session.rewardXp,
                rewardCoins: session.rewardCoins,
                leveledUp: session.leveledUp,
                onDone: () => Navigator.of(context).pop(),
              );
            }

            final question = session.currentQuestion;
            if (question == null) {
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        quizType.emptyStateLabel,
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Choose Another Mode',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              );
            }

            void handleAnswer(Answer answer) {
              ref
                  .read(quizControllerProvider(request).notifier)
                  .submitAnswer(answer);
            }

            if (question is McqQuestion) {
              final currentStreak = session.records
                  .where((record) => record.evaluation.isCorrect)
                  .length;
              final appStreak =
                  ref
                      .watch(streakControllerProvider)
                      .valueOrNull
                      ?.currentStreak ??
                  0;
              final wallet = ref.watch(walletControllerProvider).valueOrNull;
              final bestStreak = appStreak > currentStreak
                  ? appStreak
                  : currentStreak;

              return McqQuestionView(
                question: question,
                currentIndex: session.currentIndex,
                totalQuestions: session.questions.length,
                currentStreak: bestStreak,
                coins: wallet?.coins ?? 0,
                energy: wallet?.gems ?? 0,
                onExit: () => Navigator.of(context).maybePop(),
                onSubmit: handleAnswer,
              );
            }

            if (question is MatchTheFollowingQuestion) {
              return MatchTheFollowingView(
                question: question,
                onSubmit: handleAnswer,
                onExit: () => Navigator.of(context).maybePop(),
              );
            }

            if (question is SuddenDeathQuestion) {
              final currentStreak = session.records
                  .where((record) => record.evaluation.isCorrect)
                  .length;
              final appStreak =
                  ref
                      .watch(streakControllerProvider)
                      .valueOrNull
                      ?.currentStreak ??
                  0;
              final wallet = ref.watch(walletControllerProvider).valueOrNull;
              final bestStreak = appStreak > currentStreak
                  ? appStreak
                  : currentStreak;

              return SuddenDeathQuestionView(
                question: question,
                currentIndex: session.currentIndex,
                totalQuestions: session.questions.length,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                energy: wallet?.gems ?? 0,
                coins: wallet?.coins ?? 0,
                onExit: () => Navigator.of(context).maybePop(),
                onSubmit: handleAnswer,
              );
            }

            if (question is SortItRightQuestion) {
              final currentStreak = session.records
                  .where((record) => record.evaluation.isCorrect)
                  .length;
              final appStreak =
                  ref
                      .watch(streakControllerProvider)
                      .valueOrNull
                      ?.currentStreak ??
                  0;
              final wallet = ref.watch(walletControllerProvider).valueOrNull;
              final bestStreak = appStreak > currentStreak
                  ? appStreak
                  : currentStreak;

              return SortItRightView(
                question: question,
                currentIndex: session.currentIndex,
                totalQuestions: session.questions.length,
                currentStreak: bestStreak,
                coins: wallet?.coins ?? 0,
                energy: wallet?.gems ?? 0,
                onExit: () => Navigator.of(context).maybePop(),
                onSubmit: handleAnswer,
              );
            }

            return Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuizProgressHeader(
                    currentIndex: session.currentIndex,
                    totalQuestions: session.questions.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: switch (question) {
                      McqQuestion() => throw StateError(
                        'MCQ questions render above.',
                      ),
                      SortItRightQuestion() => throw StateError(
                        'Sort It Out questions render above.',
                      ),
                      SuddenDeathQuestion() => throw StateError(
                        'Sudden Death questions render above.',
                      ),
                      MatchTheFollowingQuestion() => throw StateError(
                        'Match questions render above.',
                      ),
                    },
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

class _QuizProgressHeader extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;

  const _QuizProgressHeader({
    required this.currentIndex,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final progress = totalQuestions == 0
        ? 0.0
        : (currentIndex + 1) / totalQuestions;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sports_esports_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Question ${currentIndex + 1} of $totalQuestions',
                    style: context.appTextStyles.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(
              value: progress,
              height: 7,
              semanticLabel: 'Quiz progress',
            ),
          ],
        ),
      ),
    );
  }
}
