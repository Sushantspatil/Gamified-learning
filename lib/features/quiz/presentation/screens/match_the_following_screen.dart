import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/match_the_following_models.dart';
import '../providers/match_the_following_providers.dart';
import '../providers/quiz_providers.dart';
import '../widgets/match_the_following_result_view.dart';

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

  final GlobalKey _boardKey = GlobalKey();
  final Map<String, GlobalKey> _leftAnchorKeys = {};
  final Map<String, GlobalKey> _rightAnchorKeys = {};
  Map<String, Offset> _leftAnchors = {};
  Map<String, Offset> _rightAnchors = {};
  bool _measurementScheduled = false;

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

  GlobalKey _anchorKey(Map<String, GlobalKey> keys, String id) {
    return keys.putIfAbsent(id, GlobalKey.new);
  }

  bool _areOffsetsEqual(Map<String, Offset> a, Map<String, Offset> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if ((entry.value.dx - other.dx).abs() > 0.5 ||
          (entry.value.dy - other.dy).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  void _scheduleMeasurements() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final boardBox = _boardKey.currentContext?.findRenderObject();
      if (boardBox is! RenderBox || !boardBox.hasSize) return;

      Map<String, Offset> measure(Map<String, GlobalKey> keys) {
        final map = <String, Offset>{};
        for (final entry in keys.entries) {
          final box = entry.value.currentContext?.findRenderObject();
          if (box is! RenderBox || !box.hasSize) continue;
          map[entry.key] = boardBox.globalToLocal(
            box.localToGlobal(box.size.center(Offset.zero)),
          );
        }
        return map;
      }

      final nextLeft = measure(_leftAnchorKeys);
      final nextRight = measure(_rightAnchorKeys);

      if (_areOffsetsEqual(nextLeft, _leftAnchors) &&
          _areOffsetsEqual(nextRight, _rightAnchors)) {
        return;
      }

      setState(() {
        _leftAnchors = nextLeft;
        _rightAnchors = nextRight;
      });
    });
  }

  Future<void> _confirmExit() async {
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

    if (confirmed == true && mounted) {
      await ref
          .read(matchTheFollowingControllerProvider(_request).notifier)
          .abandonSession();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;
    final asyncState = ref.watch(matchTheFollowingControllerProvider(_request));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: asyncState.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: colors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      err is AppException ? err.message : 'Failed to start game.',
                      textAlign: TextAlign.center,
                      style: textStyles.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Back',
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

              return _buildGameBoard(context, state, board, colors, textStyles);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard(
    BuildContext context,
    MatchTheFollowingViewState state,
    MatchBoard board,
    AppThemeColors colors,
    AppTextStyles textStyles,
  ) {
    final controller =
        ref.read(matchTheFollowingControllerProvider(_request).notifier);

    final totalLimitMs = board.timeLimitSec * 1000;
    final progress = totalLimitMs > 0
        ? (state.remainingMs / totalLimitMs).clamp(0.0, 1.0)
        : 0.0;

    final Color timerColor;
    if (progress > 0.4) {
      timerColor = colors.success;
    } else if (progress > 0.2) {
      timerColor = colors.warning;
    } else {
      timerColor = colors.error;
    }

    final remainingSec = (state.remainingMs / 1000).ceil();
    final totalPairs = board.leftItems.length;
    final matchedCount = state.correctMatches.length;

    const cardHeight = 64.0;
    const rowGap = 12.0;
    final boardContentHeight = math.max(
      board.leftItems.length,
      board.rightItems.length,
    ) * (cardHeight + rowGap);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top bar: Back, Title, Board Counter, Remaining time
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _confirmExit,
                tooltip: 'Exit Game',
              ),
              Expanded(
                child: Text(
                  'Match the Following',
                  style: textStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Board ${state.currentBoardIndex + 1} / ${state.boards.length}',
                  style: textStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: timerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: timerColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: timerColor),
                    const SizedBox(width: 4),
                    Text(
                      '${remainingSec}s',
                      style: textStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // 2. Urgent horizontal timer progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // 3. HUD: Pairs Matched & Mistakes counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Matched: $matchedCount / $totalPairs',
                style: textStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (board.hint != null && board.hint!.isNotEmpty)
                    TextButton.icon(
                      onPressed: controller.toggleHint,
                      icon: Icon(
                        state.isHintVisible
                            ? Icons.lightbulb
                            : Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.coinGold,
                      ),
                      label: Text(
                        'Hint',
                        style: textStyles.labelSmall.copyWith(
                          color: AppColors.coinGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (state.mistakes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Mistakes: ${state.mistakes}',
                        style: textStyles.labelSmall.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 4. Board Hint Card (if toggled)
          if (state.isHintVisible && board.hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              variant: AppCardVariant.tinted,
              tintColor: colors.primary,
              borderRadius: AppDimensions.radiusMd,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      board.hint!,
                      style: textStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // 5. Board Prompt
          Text(
            board.prompt,
            style: textStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 6. Two-column matching canvas
          SizedBox(
            height: boardContentHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _scheduleMeasurements();
                return Stack(
                  key: _boardKey,
                  children: [
                    // Connector Line Layer
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BoardConnectorPainter(
                            leftItems: board.leftItems,
                            rightItems: board.rightItems,
                            correctMatches: state.correctMatches,
                            leftAnchors: _leftAnchors,
                            rightAnchors: _rightAnchors,
                            selectedLeftId: state.selectedLeftId,
                            wrongLeftId: state.lastWrongAttemptLeftId,
                            wrongRightId: state.lastWrongAttemptRightId,
                            successColor: colors.success,
                            errorColor: colors.error,
                            selectedColor: colors.primary,
                          ),
                        ),
                      ),
                    ),

                    // Columns Layer
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          child: Column(
                            children: [
                              for (final leftItem in board.leftItems) ...[
                                _MatchCardWidget(
                                  id: leftItem.id,
                                  text: leftItem.text,
                                  anchorKey: _anchorKey(_leftAnchorKeys, leftItem.id),
                                  isLeft: true,
                                  isLocked: state.correctMatches.containsKey(leftItem.id),
                                  isSelected: state.selectedLeftId == leftItem.id,
                                  isWrongAttempt: state.lastWrongAttemptLeftId == leftItem.id,
                                  onTap: () => controller.selectLeft(leftItem.id),
                                ),
                                const SizedBox(height: rowGap),
                              ],
                            ],
                          ),
                        ),

                        // Gap between columns for connector lines
                        const SizedBox(width: 48),

                        // Right Column (shuffled order preserved directly from backend!)
                        Expanded(
                          child: Column(
                            children: [
                              for (final rightItem in board.rightItems) ...[
                                _MatchCardWidget(
                                  id: rightItem.id,
                                  text: rightItem.text,
                                  anchorKey: _anchorKey(_rightAnchorKeys, rightItem.id),
                                  isLeft: false,
                                  isLocked: state.correctMatches.containsValue(rightItem.id),
                                  isSelected: false,
                                  isWrongAttempt: state.lastWrongAttemptRightId == rightItem.id,
                                  onTap: () => controller.selectRight(rightItem.id),
                                ),
                                const SizedBox(height: rowGap),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCardWidget extends StatelessWidget {
  final String id;
  final String text;
  final GlobalKey anchorKey;
  final bool isLeft;
  final bool isLocked;
  final bool isSelected;
  final bool isWrongAttempt;
  final VoidCallback onTap;

  const _MatchCardWidget({
    required this.id,
    required this.text,
    required this.anchorKey,
    required this.isLeft,
    required this.isLocked,
    required this.isSelected,
    required this.isWrongAttempt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final textStyles = context.appTextStyles;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isLocked) {
      bgColor = colors.success.withValues(alpha: 0.14);
      borderColor = colors.success;
      textColor = colors.textPrimary;
    } else if (isWrongAttempt) {
      bgColor = colors.error.withValues(alpha: 0.18);
      borderColor = colors.error;
      textColor = colors.error;
    } else if (isSelected) {
      bgColor = colors.primary.withValues(alpha: 0.16);
      borderColor = colors.primary;
      textColor = colors.primary;
    } else {
      bgColor = colors.surface;
      borderColor = colors.border;
      textColor = colors.textPrimary;
    }

    final anchor = Container(
      key: anchorKey,
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
        border: Border.all(color: colors.background, width: 2),
      ),
    );

    return AppPressable(
      key: Key(isLeft ? 'match-left-$id' : 'match-right-$id'),
      onTap: isLocked ? () {} : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMd),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            if (!isLeft) ...[
              anchor,
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                text,
                style: textStyles.bodySmall.copyWith(
                  fontWeight: isSelected || isLocked ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: isLeft ? TextAlign.left : TextAlign.right,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: colors.success,
              ),
            ],
            if (isLeft) ...[
              const SizedBox(width: AppSpacing.xs),
              anchor,
            ],
          ],
        ),
      ),
    );
  }
}

class _BoardConnectorPainter extends CustomPainter {
  final List<MatchPairItem> leftItems;
  final List<MatchPairItem> rightItems;
  final Map<String, String> correctMatches;
  final Map<String, Offset> leftAnchors;
  final Map<String, Offset> rightAnchors;
  final String? selectedLeftId;
  final String? wrongLeftId;
  final String? wrongRightId;
  final Color successColor;
  final Color errorColor;
  final Color selectedColor;

  _BoardConnectorPainter({
    required this.leftItems,
    required this.rightItems,
    required this.correctMatches,
    required this.leftAnchors,
    required this.rightAnchors,
    this.selectedLeftId,
    this.wrongLeftId,
    this.wrongRightId,
    required this.successColor,
    required this.errorColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw confirmed correct connector curves
    final successPaint = Paint()
      ..color = successColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final entry in correctMatches.entries) {
      final p1 = leftAnchors[entry.key];
      final p2 = rightAnchors[entry.value];
      if (p1 != null && p2 != null) {
        final path = Path()..moveTo(p1.dx, p1.dy);
        final dx = (p2.dx - p1.dx) / 2;
        path.cubicTo(p1.dx + dx, p1.dy, p2.dx - dx, p2.dy, p2.dx, p2.dy);
        canvas.drawPath(path, successPaint);
      }
    }

    // 2. Draw wrong attempt flash curve
    if (wrongLeftId != null && wrongRightId != null) {
      final p1 = leftAnchors[wrongLeftId];
      final p2 = rightAnchors[wrongRightId];
      if (p1 != null && p2 != null) {
        final errorPaint = Paint()
          ..color = errorColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final path = Path()..moveTo(p1.dx, p1.dy);
        final dx = (p2.dx - p1.dx) / 2;
        path.cubicTo(p1.dx + dx, p1.dy, p2.dx - dx, p2.dy, p2.dx, p2.dy);
        canvas.drawPath(path, errorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardConnectorPainter oldDelegate) {
    return !mapEquals(correctMatches, oldDelegate.correctMatches) ||
        !mapEquals(leftAnchors, oldDelegate.leftAnchors) ||
        !mapEquals(rightAnchors, oldDelegate.rightAnchors) ||
        selectedLeftId != oldDelegate.selectedLeftId ||
        wrongLeftId != oldDelegate.wrongLeftId ||
        wrongRightId != oldDelegate.wrongRightId;
  }
}
