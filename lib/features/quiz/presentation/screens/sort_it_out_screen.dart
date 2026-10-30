import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../providers/quiz_providers.dart';
import '../providers/sort_it_out_providers.dart';
import '../widgets/sort_it_out_result_view.dart';
import '../widgets/sort_it_right_view.dart';
import '../../../../shared/widgets/game_scaffold.dart';

/// Dedicated standalone screen for rapid-fire Sort It Out swipe mini-game.
class SortItOutScreen extends ConsumerStatefulWidget {
  final String topicId;
  final String? subjectId;
  final String? chapterId;

  const SortItOutScreen({
    super.key,
    required this.topicId,
    this.subjectId,
    this.chapterId,
  });

  @override
  ConsumerState<SortItOutScreen> createState() => _SortItOutScreenState();
}

class _SortItOutScreenState extends ConsumerState<SortItOutScreen>
    with WidgetsBindingObserver {
  late final QuizSessionRequest _request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _request = QuizSessionRequest(
      topicId: widget.topicId,
      quizType: QuestionType.sortItRight,
      subjectId: widget.subjectId,
      chapterId: widget.chapterId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(sortItOutControllerProvider(_request).notifier)
          .resyncAfterResume();
    }
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(sortItOutControllerProvider(_request)).valueOrNull;
    if (state == null || state.result != null || state.cards.isEmpty) {
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Sort It Out?'),
        content: const Text(
          'Your progress in this rapid-fire round will be abandoned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Quit round'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await ref
          .read(sortItOutControllerProvider(_request).notifier)
          .abandonSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final stateAsync = ref.watch(sortItOutControllerProvider(_request));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GameScaffold(
        body: SafeArea(
          child: stateAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 52,
                      color: colors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to load Sort It Out.',
                      style: context.appTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Retry',
                      onPressed: () =>
                          ref.invalidate(sortItOutControllerProvider(_request)),
                    ),
                  ],
                ),
              ),
            ),
            data: (session) {
              // 1. Completion Loading Screen
              if (session.isCompleting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Calculating your results...',
                        style: context.appTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Authoritative grading & economy calculation with the backend',
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 2. Completion Network Failure & Retry
              if (session.completionError != null) {
                return Center(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 52,
                          color: colors.error,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Couldn\'t submit your results.',
                          style: context.appTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Check your connection and retry.',
                          style: context.appTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: 'Retry',
                          onPressed: () => ref
                              .read(sortItOutControllerProvider(_request).notifier)
                              .retryCompletion(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 3. Final Official Results Screen
              if (session.result != null) {
                return SortItOutResultView(
                  result: session.result!,
                  onDone: () => Navigator.of(context).pop(),
                  onPlayAgain: () =>
                      ref.invalidate(sortItOutControllerProvider(_request)),
                );
              }

              // 4. Empty State
              if (session.cards.isEmpty) {
                return Center(
                  child: AppEmptyState(
                    title: 'Sort It Out',
                    description: 'No classification cards available for this topic.',
                    action: AppButton(
                      label: 'Go back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              }

              final controller = ref.read(
                sortItOutControllerProvider(_request).notifier,
              );
              final wallet = ref.watch(walletControllerProvider).valueOrNull;

              return SortItRightView(
                cards: session.cards,
                currentIndex: session.currentIndex,
                totalQuestions: session.cards.length,
                currentStreak: session.currentCombo,
                coins: wallet?.coins ?? 0,
                energy: wallet?.gems ?? 0,
                onOptionSubmitted: (option) => controller.submitOption(option),
                onTimeout: () => controller.handleTimeout(),
                onExit: () async {
                  final shouldPop = await _onWillPop();
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
