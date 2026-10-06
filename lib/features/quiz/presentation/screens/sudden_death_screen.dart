import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../providers/quiz_providers.dart';
import '../providers/sudden_death_providers.dart';
import '../widgets/quiz_result_view.dart';
import '../widgets/sudden_death_question_view.dart';

/// Dedicated standalone screen for the real-time Sudden Death survival mode.
///
/// Decoupled from standard quiz screens to provide an isolated game loop,
/// authoritative WebSocket sync, survival feedback, and dedicated lifecycle.
class SuddenDeathScreen extends ConsumerWidget {
  final String topicId;
  final String? subjectId;
  final String? chapterId;

  const SuddenDeathScreen({
    super.key,
    required this.topicId,
    this.subjectId,
    this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.themeColors;
    final request = QuizSessionRequest(
      topicId: topicId,
      quizType: QuestionType.suddenDeath,
      subjectId: subjectId,
      chapterId: chapterId,
    );

    final suddenAsync = ref.watch(suddenDeathControllerProvider(request));

    return GameScaffold(
      body: SafeArea(
        child: suddenAsync.when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppColors.streakFire,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Entering Sudden Death Arena...',
                  style: context.appTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Connecting to real-time engine',
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 56, color: colors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Sudden Death Connection Error',
                    style: context.appTextStyles.titleLarge.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppButton(
                        label: 'Go Back',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: 'Retry',
                        onPressed: () => ref
                            .read(
                              suddenDeathControllerProvider(request).notifier,
                            )
                            .retry(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          data: (suddenState) {
            if (suddenState.status == SuddenDeathStatus.connecting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: AppColors.streakFire,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Entering Sudden Death Arena...',
                      style: context.appTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Connecting to real-time engine',
                      style: context.appTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (suddenState.status == SuddenDeathStatus.error) {
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 56,
                        color: colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Could Not Join Live Game',
                        style: context.appTextStyles.titleLarge.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        suddenState.errorMessage ?? 'An error occurred.',
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppButton(
                            label: 'Go Back',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          AppButton(
                            label: 'Retry',
                            onPressed: () => ref
                                .read(
                                  suddenDeathControllerProvider(
                                    request,
                                  ).notifier,
                                )
                                .retry(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            if (suddenState.status == SuddenDeathStatus.gameOver &&
                suddenState.result != null) {
              return QuizResultView(
                result: suddenState.result!,
                rewardXp: suddenState.result!.xpAwarded,
                rewardCoins: suddenState.result!.coinsAwarded,
                leveledUp: suddenState.result!.didLevelUp,
                onDone: () => Navigator.of(context).pop(),
                onPlayAgain: () =>
                    ref.invalidate(suddenDeathControllerProvider(request)),
              );
            }

            if (suddenState.isSubmitting && suddenState.result == null) {
              return Center(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: AppColors.streakFire,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Calculating Survival Results...',
                        style: context.appTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Finalizing points & rewards with backend',
                        style: context.appTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final question = suddenState.currentQuestion;
            if (question == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final appStreak =
                ref
                    .watch(streakControllerProvider)
                    .valueOrNull
                    ?.currentStreak ??
                0;
            final bestStreak = appStreak > suddenState.currentStreak
                ? appStreak
                : suddenState.currentStreak;

            final wallet = ref.watch(walletControllerProvider).valueOrNull;

            return Column(
              children: [
                if (suddenState.errorMessage != null &&
                    suddenState.status != SuddenDeathStatus.error)
                  _SuddenDeathLiveErrorBanner(
                    message: suddenState.errorMessage!,
                  ),
                Expanded(
                  child: SuddenDeathQuestionView(
                    question: question,
                    currentIndex: suddenState.currentIndex,
                    totalQuestions: suddenState.totalQuestions,
                    currentStreak: suddenState.currentStreak,
                    bestStreak: bestStreak,
                    energy: wallet?.gems ?? 0,
                    coins: wallet?.coins ?? 0,
                    remainingTimeMs: suddenState.remainingTimeMs,
                    externalSkipUsed: suddenState.skipUsed,
                    serverAnswerResult: suddenState.lastAnswerResult,
                    isSubmitting: suddenState.isSubmitting,
                    externalSelectedOptionId: suddenState.selectedOptionId,
                    onExit: () {
                      final notifier = ref.read(
                        suddenDeathControllerProvider(request).notifier,
                      );
                      unawaited(notifier.abandon());
                      Navigator.of(context).maybePop();
                    },
                    onSelectOption: (opt) => ref
                        .read(suddenDeathControllerProvider(request).notifier)
                        .submitAnswer(opt),
                    onTimeout: () => ref
                        .read(suddenDeathControllerProvider(request).notifier)
                        .handleTimeout(),
                    onSkip: () => ref
                        .read(suddenDeathControllerProvider(request).notifier)
                        .skipQuestion(),
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

class _SuddenDeathLiveErrorBanner extends StatelessWidget {
  final String message;

  const _SuddenDeathLiveErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: colors.error.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, size: 18, color: colors.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.bodySmall.copyWith(
                color: colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
