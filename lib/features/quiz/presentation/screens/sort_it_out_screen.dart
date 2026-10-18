import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_choice_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../questions/domain/entities/question.dart';
import '../providers/quiz_providers.dart';
import '../providers/sort_it_out_providers.dart';
import '../widgets/sort_it_out_result_view.dart';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final QuizSessionRequest _request;
  late final AnimationController _cardAnimController;

  double _dragOffset = 0.0;
  String? _targetOption;

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
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cardAnimController.dispose();
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

  void _handleButtonTap(String option) {
    final state = ref.read(sortItOutControllerProvider(_request)).valueOrNull;
    if (state == null || state.cardResolved || state.isCompleting) return;

    setState(() {
      _targetOption = option;
      _dragOffset = option == 'a' ? -150.0 : 150.0;
    });

    _cardAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
          _targetOption = null;
        });
      }
    });

    ref
        .read(sortItOutControllerProvider(_request).notifier)
        .submitOption(option);
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
            loading: () => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Loading Sort It Out deck...',
                    style: context.appTextStyles.bodyLarge,
                  ),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: AppSpacing.paddingLg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not start Sort It Out round.',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodySmall.copyWith(
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

              final currentCard = session.currentCard;
              if (currentCard == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final nextCard = session.nextCard;
              final total = session.cards.length;
              final displayIndex = (session.currentIndex + 1).clamp(1, total);

              // Timer visual urgency: cyan (>40%) -> amber (20-40%) -> red (<20%)
              final progress = session.timerProgress;
              final timerColor = progress > 0.4
                  ? colors.primary
                  : progress > 0.2
                      ? colors.warning
                      : colors.error;

              final secondsRemaining =
                  (session.timeRemainingMs / 1000).clamp(0.0, 60.0);

              return Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top App Header
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () async {
                            final shouldPop = await _onWillPop();
                            if (shouldPop && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Sort It Out',
                            style: context.appTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '$displayIndex / $total',
                          style: context.appTextStyles.labelLarge.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Status Bar: Streak + Timer Seconds
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.streakFire.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 16,
                                color: AppColors.streakFire,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${session.currentCombo} Streak',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.streakFire,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${secondsRemaining.toStringAsFixed(1)} sec',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: timerColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Smooth Horizontal Urgency Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: colors.surface.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Binary Category Header Prompts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '← ${currentCard.labelA.toUpperCase()}',
                          style: context.appTextStyles.labelLarge.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${currentCard.labelB.toUpperCase()} →',
                          style: context.appTextStyles.labelLarge.copyWith(
                            color: colors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Interactive Card Stack Area
                    Expanded(
                      child: LayoutBuilder(
                        key: const Key('sort-playfield'),
                        builder: (context, constraints) {
                          final cardWidth =
                              math.min(360.0, constraints.maxWidth - 24);
                          final cardHeight = math.min(
                            280.0,
                            constraints.maxHeight - 20,
                          );

                          return Center(
                            child: SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Underneath Next Card (Scale 0.95, Opacity 0.8)
                                  if (nextCard != null)
                                    Transform.scale(
                                      scale: 0.95,
                                      child: Opacity(
                                        opacity: 0.75,
                                        child: AppCard(
                                          elevationLevel: 1,
                                          padding: AppSpacing.paddingLg,
                                          child: Center(
                                            child: Text(
                                              nextCard.prompt,
                                              textAlign: TextAlign.center,
                                              style: context
                                                  .appTextStyles.titleLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Active Current Card with Drag & Physics
                                  GestureDetector(
                                    key: const Key('sort-active-card'),
                                    onHorizontalDragStart: (_) {
                                      if (session.cardResolved ||
                                          session.isCompleting) {
                                        return;
                                      }
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      if (session.cardResolved ||
                                          session.isCompleting) {
                                        return;
                                      }
                                      setState(() {
                                        _dragOffset += details.delta.dx;
                                      });
                                    },
                                    onHorizontalDragEnd: (details) {
                                      if (session.cardResolved ||
                                          session.isCompleting) {
                                        return;
                                      }

                                      final threshold = cardWidth * 0.32;
                                      final velocity =
                                          details.primaryVelocity ?? 0;

                                      if (_dragOffset < -threshold ||
                                          velocity < -650) {
                                        _handleButtonTap('a');
                                      } else if (_dragOffset > threshold ||
                                          velocity > 650) {
                                        _handleButtonTap('b');
                                      } else {
                                        // Spring back to center
                                        setState(() => _dragOffset = 0);
                                      }
                                    },
                                    onHorizontalDragCancel: () {
                                      setState(() {
                                        _dragOffset = 0;
                                      });
                                    },
                                    child: Transform.translate(
                                      offset: Offset(_dragOffset, 0),
                                      child: Transform.rotate(
                                        angle: (_dragOffset / cardWidth)
                                            .clamp(-0.24, 0.24),
                                        child: _ActiveCardWidget(
                                          prompt: currentCard.prompt,
                                          dragOffset: _dragOffset,
                                          labelA: currentCard.labelA,
                                          labelB: currentCard.labelB,
                                          feedback:
                                              session.lastProvisionalFeedback,
                                          cardResolved: session.cardResolved,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Gesture guidance instruction
                    Text(
                      'Swipe left or right, or tap the buttons below',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Accessible Classification Buttons (Option A / Option B)
                    Row(
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: const ValueKey('sort-bucket-debit'),
                            child: AppChoiceCard(
                              key: const ValueKey('sort-bucket-a'),
                              label: currentCard.labelA,
                              icon: Icons.west_rounded,
                              accentColor: colors.primary,
                              selected: _targetOption == 'a',
                              onPressed: (session.cardResolved ||
                                      session.isCompleting)
                                  ? null
                                  : () => _handleButtonTap('a'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: KeyedSubtree(
                            key: const ValueKey('sort-bucket-credit'),
                            child: AppChoiceCard(
                              key: const ValueKey('sort-bucket-b'),
                              label: currentCard.labelB,
                              icon: Icons.east_rounded,
                              accentColor: colors.secondary,
                              selected: _targetOption == 'b',
                              onPressed: (session.cardResolved ||
                                      session.isCompleting)
                                  ? null
                                  : () => _handleButtonTap('b'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveCardWidget extends StatelessWidget {
  final String prompt;
  final double dragOffset;
  final String labelA;
  final String labelB;
  final SortItOutProvisionalFeedback? feedback;
  final bool cardResolved;

  const _ActiveCardWidget({
    required this.prompt,
    required this.dragOffset,
    required this.labelA,
    required this.labelB,
    this.feedback,
    required this.cardResolved,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    Color borderColor = colors.primary.withValues(alpha: 0.25);
    Color? glowColor;

    if (feedback != null) {
      if (feedback!.isTimeout) {
        borderColor = colors.warning;
        glowColor = colors.warning.withValues(alpha: 0.35);
      } else if (feedback!.isCorrect) {
        borderColor = colors.success;
        glowColor = colors.success.withValues(alpha: 0.35);
      } else {
        borderColor = colors.error;
        glowColor = colors.error.withValues(alpha: 0.35);
      }
    } else if (dragOffset < -25) {
      borderColor = colors.primary;
    } else if (dragOffset > 25) {
      borderColor = colors.secondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor,
              blurRadius: 18,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: AppSpacing.paddingLg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Drag side indicator tag
          if (dragOffset < -25)
            Text(
              '← $labelA',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            )
          else if (dragOffset > 25)
            Text(
              '$labelB →',
              style: TextStyle(
                color: colors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            )
          else
            const SizedBox(height: 18),

          const SizedBox(height: AppSpacing.sm),

          // Main Card Prompt Text
          Expanded(
            child: Center(
              child: Text(
                prompt,
                textAlign: TextAlign.center,
                style: context.appTextStyles.headingSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),

          // Instant Provisional Feedback Badge
          if (feedback != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  feedback!.isCorrect
                      ? Icons.check_circle_outline
                      : feedback!.isTimeout
                          ? Icons.timer_off_outlined
                          : Icons.cancel_outlined,
                  size: 20,
                  color: borderColor,
                ),
                const SizedBox(width: 6),
                Text(
                  feedback!.isTimeout
                      ? 'TIME\'S UP'
                      : feedback!.isCorrect
                          ? 'CORRECT'
                          : 'WRONG',
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
