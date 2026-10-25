import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/question.dart';
import '../providers/match_the_following_providers.dart';
import '../providers/quiz_providers.dart';
import '../widgets/match_the_following_result_view.dart';
import '../widgets/match_the_following_view.dart';

/// Interactive multi-board Match the Following game screen.
class MatchTheFollowingScreen extends ConsumerStatefulWidget {
  final String topicId;
  final String? subjectId;
  final String? chapterId;

  const MatchTheFollowingScreen({
    super.key,
    required this.topicId,
    this.subjectId,
    this.chapterId,
  });

  @override
  ConsumerState<MatchTheFollowingScreen> createState() =>
      _MatchTheFollowingScreenState();
}

class _MatchTheFollowingScreenState extends ConsumerState<MatchTheFollowingScreen>
    with WidgetsBindingObserver {
  QuizSessionRequest get _request => QuizSessionRequest(
        topicId: widget.topicId,
        quizType: QuestionType.matchTheFollowing,
        subjectId: widget.subjectId,
        chapterId: widget.chapterId,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(matchTheFollowingControllerProvider(_request).notifier).checkAppResumed();
    }
  }

  Future<bool> _handleExit() async {
    final state =
        ref.read(matchTheFollowingControllerProvider(_request)).valueOrNull;
    if (state == null || state.result != null || state.boards.isEmpty) {
      return true;
    }

    final colors = context.themeColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Match Game?'),
        content: const Text(
          'Leaving now will abandon this game session. Your progress will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Exit Game',
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(matchTheFollowingControllerProvider(_request).notifier)
          .abandonSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;
    final asyncState = ref.watch(matchTheFollowingControllerProvider(_request));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleExit();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: asyncState.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: colors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      error is AppException
                          ? error.message
                          : 'Unable to start Match game.',
                      textAlign: TextAlign.center,
                      style: textStyles.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Go Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            data: (state) {
              // 1. Authoritative Results screen
              if (state.result != null) {
                return MatchTheFollowingResultView(
                  result: state.result!,
                  onDone: () => Navigator.of(context).pop(),
                );
              }

              // 2. Completion loading screen
              if (state.isCompleting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Calculating your results...',
                        style: textStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Verifying board matches with the backend',
                        style: textStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 3. Completion network failure retry screen
              if (state.completionError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: colors.warning,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          state.completionError!,
                          textAlign: TextAlign.center,
                          style: textStyles.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: 'Retry',
                          onPressed: () => ref
                              .read(matchTheFollowingControllerProvider(_request).notifier)
                              .retryCompletion(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final board = state.currentBoard;
              if (board == null) return const SizedBox.shrink();

              final controller = ref.read(
                matchTheFollowingControllerProvider(_request).notifier,
              );

              return MatchTheFollowingView(
                board: board,
                title: widget.topicId,
                currentIndex: state.currentBoardIndex,
                totalQuestions: state.boards.length,
                selectedLeftId: state.selectedLeftId,
                confirmedMatches: state.correctMatches,
                lastWrongAttemptLeftId: state.lastWrongAttemptLeftId,
                lastWrongAttemptRightId: state.lastWrongAttemptRightId,
                onBoardSubmit: (matches, mistakes) => controller.submitBoard(
                  matches: matches,
                  mistakes: mistakes,
                ),
                onLeftTap: (leftId) => controller.selectLeft(leftId),
                onRightTap: (rightId) => controller.selectRight(rightId),
                onExit: () async {
                  final shouldPop = await _handleExit();
                  if (shouldPop && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
