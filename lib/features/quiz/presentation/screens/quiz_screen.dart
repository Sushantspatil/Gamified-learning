import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../providers/quiz_providers.dart';
import '../widgets/match_the_following_view.dart';
import '../widgets/mcq_question_view.dart';
import '../widgets/quiz_result_view.dart';
import '../widgets/sort_it_right_view.dart';
import '../widgets/sudden_death_question_view.dart';

class QuizScreen extends ConsumerWidget {
  final String topicId;

  const QuizScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(quizControllerProvider(topicId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
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
                  Text('Could not load this quiz.', style: context.appTextStyles.bodyLarge),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(quizControllerProvider(topicId)),
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
              return Center(child: Text('No questions available.', style: context.appTextStyles.bodyLarge));
            }

            void handleAnswer(Answer answer) {
              ref.read(quizControllerProvider(topicId).notifier).submitAnswer(answer);
            }

            return Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Question ${session.currentIndex + 1} of ${session.questions.length}',
                    style: context.appTextStyles.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: switch (question) {
                      McqQuestion q => McqQuestionView(question: q, onSubmit: handleAnswer),
                      SuddenDeathQuestion q =>
                        SuddenDeathQuestionView(question: q, onSubmit: handleAnswer),
                      MatchTheFollowingQuestion q =>
                        MatchTheFollowingView(question: q, onSubmit: handleAnswer),
                      SortItRightQuestion q => SortItRightView(question: q, onSubmit: handleAnswer),
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
