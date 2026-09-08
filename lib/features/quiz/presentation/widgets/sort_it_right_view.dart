import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_choice_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';

const sortFallDuration = Duration(seconds: 4);
const sortExitDuration = Duration(milliseconds: 320);
const sortFeedbackDuration = Duration(milliseconds: 600);

enum SortTimeoutBehavior { miss, waitForAnswer }

enum _SortPhase { intro, falling, exiting, feedback, finished }

class SortItRightView extends StatefulWidget {
  final SortItRightQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int coins;
  final int energy;
  final VoidCallback onExit;
  final void Function(Answer answer) onSubmit;
  final Duration fallDuration;
  final SortTimeoutBehavior timeoutBehavior;

  const SortItRightView({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.coins,
    required this.energy,
    required this.onExit,
    required this.onSubmit,
    this.fallDuration = sortFallDuration,
    this.timeoutBehavior = SortTimeoutBehavior.miss,
  }) : assert(fallDuration > Duration.zero);

  @override
  State<SortItRightView> createState() => _SortItRightViewState();
}

class _SortItRightViewState extends State<SortItRightView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // A null choice is an explicit miss, keeping item indexes and Undo aligned.
  final List<SortSide?> _history = [];
  final _stageKey = GlobalKey();
  final _leftKey = GlobalKey();
  final _rightKey = GlobalKey();
  final _dragX = ValueNotifier<double>(0);
  late final AnimationController _fallController;
  late final AnimationController _exitController;
  late final Listenable _cardMotion;
  Timer? _feedbackTimer;
  _SortPhase _phase = _SortPhase.intro;
  Offset _exitStart = Offset.zero;
  Offset _exitTarget = Offset.zero;
  Size _stageSize = Size.zero;
  double _cardHeight = 144;
  bool _isDragging = false;
  bool _powerUpBusy = false;
  bool _helpVisible = false;
  bool _appActive = true;
  bool _reducedMotion = false;
  bool _hintUsed = false;
  bool _revealUsed = false;
  int? _hintIndex;
  int? _revealedIndex;
  SortSide? _activeSide;

  int get _currentItemIndex => _history.length;
  bool get _complete =>
      _currentItemIndex >= widget.question.itemsInOrder.length;
  bool get _canClassify =>
      _phase == _SortPhase.falling &&
      !_complete &&
      !_powerUpBusy &&
      !_helpVisible &&
      _appActive;
  double get _fallDistance => math.max(0, _stageSize.height - _cardHeight);
  double get _fallY =>
      _reducedMotion ? 0 : _fallController.value * _fallDistance;
  int get _correctCount => _history.indexed
      .where((move) => widget.question.correctSides[move.$1] == move.$2)
      .length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fallController = AnimationController(
      vsync: this,
      duration: widget.fallDuration,
    )..addStatusListener(_onFallStatus);
    _exitController = AnimationController(
      vsync: this,
      duration: sortExitDuration,
    );
    // Only the card's transform builder listens to ticks, never the quiz tree.
    _cardMotion = Listenable.merge([_fallController, _exitController, _dragX]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = AppMotion.reduceMotion(context);
    _resumeFall();
  }

  @override
  void didUpdateWidget(covariant SortItRightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _feedbackTimer?.cancel();
      _fallController.reset();
      _exitController.reset();
      _history.clear();
      _dragX.value = 0;
      _exitStart = _exitTarget = Offset.zero;
      _hintUsed = _revealUsed = _helpVisible = _isDragging = false;
      _hintIndex = _revealedIndex = null;
      _activeSide = null;
      _phase = widget.currentIndex > 0 ? _SortPhase.falling : _SortPhase.intro;
    }
    _fallController.duration = widget.fallDuration;
    _resumeFall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) {
      _resumeFall();
    } else {
      _fallController.stop();
    }
  }

  void _resumeFall() {
    // Reduced motion is an untimed tap/swipe alternative: a hidden timer
    // would remove the only visible urgency cue for these learners.
    if (_canClassify && !_reducedMotion && !_fallController.isCompleted) {
      if (!_fallController.isAnimating) _fallController.forward();
    } else if (!_canClassify || _reducedMotion) {
      _fallController.stop();
    }
  }

  void _onFallStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _canClassify &&
        widget.timeoutBehavior == SortTimeoutBehavior.miss) {
      _resolve(null);
    }
  }

  void _spawn() {
    _fallController.reset();
    _exitController.reset();
    _dragX.value = 0;
    _exitStart = _exitTarget = Offset.zero;
    setState(() {
      _phase = _SortPhase.falling;
      _isDragging = false;
      _activeSide = null;
      _helpVisible = false;
    });
    _resumeFall();
  }

  Future<void> _resolve(SortSide? side) async {
    if (!_canClassify) return;
    _fallController.stop();
    _exitStart = Offset(_dragX.value, _fallY);
    _exitTarget = _exitStart;
    if (side != null) {
      final stage = _stageKey.currentContext?.findRenderObject();
      final category = (side == SortSide.left ? _leftKey : _rightKey)
          .currentContext
          ?.findRenderObject();
      if (stage is RenderBox && category is RenderBox) {
        final center = stage.globalToLocal(
          category.localToGlobal(category.size.center(Offset.zero)),
        );
        _exitTarget = Offset(
          center.dx - _stageSize.width / 2,
          center.dy - _cardHeight / 2,
        );
      }
    }
    setState(() {
      _phase = _SortPhase.exiting;
      _activeSide = side;
      _isDragging = false;
    });
    _exitController.duration = AppMotion.duration(context, sortExitDuration);
    try {
      await _exitController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      _history.add(side);
      _phase = _SortPhase.feedback;
    });
    _feedbackTimer = Timer(sortFeedbackDuration, () {
      if (!mounted) return;
      if (_complete) {
        setState(() => _phase = _SortPhase.finished);
        widget.onSubmit(
          SortAnswer(
            questionId: widget.question.id,
            orderedItems: List.of(widget.question.itemsInOrder),
            selectedSides: List.unmodifiable(_history),
          ),
        );
      } else {
        _spawn();
      }
    });
  }

  void _returnCard() {
    if (!_canClassify) return;
    // Horizontal return has its own short tween; falling Y keeps advancing.
    _exitStart = Offset(_dragX.value, 0);
    _exitController.duration = AppMotion.duration(context, AppMotion.fast);
    _exitController.forward(from: 0);
    _dragX.value = 0;
    setState(() {
      _isDragging = false;
      _activeSide = null;
    });
  }

  void _undo() {
    if (_history.isEmpty || _phase != _SortPhase.falling) return;
    _fallController.stop();
    _history.removeLast();
    _spawn();
  }

  void _setPowerUpBusy(bool busy) {
    setState(() => _powerUpBusy = busy);
    _resumeFall();
  }

  void _showHelp({required bool reveal}) {
    _fallController.stop();
    setState(() {
      _helpVisible = true;
      if (reveal) {
        _revealUsed = true;
        _revealedIndex = _currentItemIndex;
      } else {
        _hintUsed = true;
        _hintIndex = _currentItemIndex;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _fallController.dispose();
    _exitController.dispose();
    _dragX.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    if (!question.hasCategories) {
      return AppEmptyState(
        title: QuestionType.sortItRight.emptyStateLabel,
        description: question.itemsInOrder.isEmpty
            ? 'Choose another topic to keep practising.'
            : 'Category information is not available for these items yet.',
        action: AppButton(label: 'Go back', onPressed: widget.onExit),
      );
    }
    final colors = context.themeColors;
    final total = question.itemsInOrder.length;
    final resolved =
        _phase == _SortPhase.feedback || _phase == _SortPhase.finished;
    final displayIndex = resolved
        ? _currentItemIndex
        : (_currentItemIndex + 1).clamp(1, total);
    return LayoutBuilder(
      builder: (context, viewport) {
        // A scroll fallback protects small phones and enlarged text; the fall
        // itself always uses the stage's actual laid-out size below.
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final canvasHeight = math.max(
          viewport.maxHeight,
          _minimumCanvasHeight(context, viewport.maxWidth, textScale),
        );
        return SingleChildScrollView(
          key: const Key('sort-scroll'),
          child: SizedBox(
            height: canvasHeight,
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Sort It Out',
                          style: context.appTextStyles.titleLarge,
                        ),
                      ),
                      Semantics(
                        label: 'Question $displayIndex of $total',
                        child: Text(
                          '$displayIndex / $total',
                          style: context.appTextStyles.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppProgressBar(
                          value: _currentItemIndex / total,
                          semanticLabel: 'Items sorted',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        Icons.monetization_on_outlined,
                        size: 18,
                        color: colors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${widget.coins}',
                        style: context.appTextStyles.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Classify each item into the correct group',
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ClipRect(
                      child: Column(
                        children: [
                          Expanded(
                            child: _phase == _SortPhase.intro
                                ? _buildIntro(context, total)
                                : _buildStage(context),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final side in SortSide.values) ...[
                                if (side == SortSide.right)
                                  const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                      side == SortSide.left
                                          ? 'sort-bucket-debit'
                                          : 'sort-bucket-credit',
                                    ),
                                    child: AppChoiceCard(
                                      key: side == SortSide.left
                                          ? _leftKey
                                          : _rightKey,
                                      label: question.categoryLabel(side),
                                      icon: side == SortSide.left
                                          ? Icons.west_rounded
                                          : Icons.east_rounded,
                                      accentColor: side == SortSide.left
                                          ? colors.primary
                                          : colors.secondary,
                                      selected:
                                          _activeSide == side ||
                                          (!_complete &&
                                              (_hintIndex ==
                                                      _currentItemIndex ||
                                                  _revealedIndex ==
                                                      _currentItemIndex) &&
                                              question.correctSides[_currentItemIndex] ==
                                                  side),
                                      onPressed: _canClassify
                                          ? () => _resolve(side)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Reserve feedback space so categories and the fall boundary do
                  // not shift when an answer resolves or a power-up is opened.
                  SizedBox(
                    height: 64 * textScale,
                    child: Center(
                      child: SingleChildScrollView(
                        child: _buildFeedback(context, resolved),
                      ),
                    ),
                  ),
                  GamePowerUpBar(
                    onBusyChanged: _setPowerUpBusy,
                    isDense: true,
                    showWallet: false,
                    isDisabled:
                        _phase != _SortPhase.falling ||
                        _isDragging ||
                        _helpVisible,
                    actions: [
                      GamePowerUpAction(
                        id: 'sort-hint',
                        label: 'Hint',
                        description: 'Pause and show a sorting clue.',
                        coinCost: 10,
                        icon: Icons.lightbulb_outline,
                        isUsed: _hintUsed,
                        onUse: () => _showHelp(reveal: false),
                      ),
                      GamePowerUpAction(
                        id: 'sort-reveal',
                        label: 'Reveal',
                        description: 'Pause and reveal the correct group.',
                        coinCost: 25,
                        icon: Icons.visibility_outlined,
                        isUsed: _revealUsed,
                        isDisabled: _complete,
                        onUse: () => _showHelp(reveal: true),
                      ),
                      GamePowerUpAction(
                        id: 'sort-undo',
                        label: 'Undo',
                        description:
                            'Restart the previous item and undo its answer.',
                        coinCost: 10,
                        icon: Icons.undo_rounded,
                        isDisabled: _history.isEmpty,
                        onUse: _undo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Size _textSize(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, width));
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double _minimumCanvasHeight(
    BuildContext context,
    double viewportWidth,
    double textScale,
  ) {
    final width = viewportWidth - AppSpacing.md * 2;
    final styles = context.appTextStyles;
    final count =
        '${widget.question.itemsInOrder.length} / ${widget.question.itemsInOrder.length}';
    final counter = _textSize(
      context,
      count,
      styles.labelLarge,
      double.infinity,
    );
    final heading = _textSize(
      context,
      'Sort It Out',
      styles.titleLarge,
      width - 48 - counter.width,
    );
    final instruction = _textSize(
      context,
      'Classify each item into the correct group',
      styles.titleMedium,
      width,
    );
    final categoryWidth = (width - AppSpacing.sm) / 2 - AppSpacing.md * 2;
    final categoryHeight = math.max(
      100.0,
      math.max(
            _textSize(
              context,
              widget.question.leftCategory,
              styles.titleMedium,
              categoryWidth,
            ).height,
            _textSize(
              context,
              widget.question.rightCategory,
              styles.titleMedium,
              categoryWidth,
            ).height,
          ) +
          AppSpacing.md * 2 +
          AppSpacing.sm +
          20,
    );
    final cardWidth = math.min(360.0, width) - AppSpacing.lg * 2;
    final tallestItem = widget.question.itemsInOrder
        .map(
          (item) =>
              _textSize(context, item, styles.titleLarge, cardWidth).height,
        )
        .reduce(math.max);
    final cardHeight = math.max(
      144.0,
      tallestItem +
          AppSpacing.lg * 2 +
          AppSpacing.md +
          MediaQuery.textScalerOf(context).scale(18),
    );
    // Reserve one card plus a visible travel lane. Everything else follows
    // measured, wrapping text, including accessibility text sizes.
    return AppSpacing.md * 2 +
        math.max(48.0, heading.height) +
        math.max(18.0, counter.height) +
        AppSpacing.md * 2 +
        instruction.height +
        cardHeight +
        AppSpacing.massive +
        AppSpacing.sm +
        categoryHeight +
        AppSpacing.sm +
        64 * textScale +
        64;
  }

  Widget _buildIntro(BuildContext context, int total) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swipe_rounded,
            size: 40,
            color: context.themeColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$total items. Two groups.',
            textAlign: TextAlign.center,
            style: context.appTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _reducedMotion ||
                    widget.timeoutBehavior == SortTimeoutBehavior.waitForAnswer
                ? 'Swipe the card or tap a group to sort each item.'
                : 'Swipe or tap a group before the card reaches the bottom. Unsorted items count as missed.',
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Start sorting', onPressed: _spawn),
        ],
      ),
    ),
  );

  Widget _buildStage(BuildContext context) {
    final resolved =
        _phase == _SortPhase.feedback || _phase == _SortPhase.finished;
    final index = resolved ? _currentItemIndex - 1 : _currentItemIndex;
    return LayoutBuilder(
      key: const Key('sort-playfield'),
      builder: (context, constraints) {
        _stageSize = constraints.biggest;
        final width = math.min(360.0, constraints.maxWidth);
        final text = TextPainter(
          text: TextSpan(
            text: widget.question.itemsInOrder[index],
            style: context.appTextStyles.titleLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: width - AppSpacing.lg * 2);
        _cardHeight = math.max(
          144.0,
          text.height +
              AppSpacing.lg * 2 +
              AppSpacing.md +
              MediaQuery.textScalerOf(context).scale(18),
        );
        text.dispose();
        return SizedBox(
          key: _stageKey,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!resolved)
                Positioned(
                  top: 0,
                  left: (constraints.maxWidth - width) / 2,
                  width: width,
                  height: _cardHeight,
                  child: AnimatedBuilder(
                    animation: _cardMotion,
                    child: GestureDetector(
                      key: const Key('sort-active-card'),
                      onHorizontalDragStart: (_) {
                        if (!_canClassify) return;
                        final returnProgress = AppMotion.easeOut.transform(
                          _exitController.value,
                        );
                        final visibleX =
                            _dragX.value + _exitStart.dx * (1 - returnProgress);
                        _exitController.value = 1;
                        _dragX.value = visibleX;
                        setState(() => _isDragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (!_canClassify) return;
                        _dragX.value = (_dragX.value + details.delta.dx).clamp(
                          -width,
                          width,
                        );
                        final side = _dragX.value < 0
                            ? SortSide.left
                            : SortSide.right;
                        if (_activeSide != side) {
                          setState(() => _activeSide = side);
                        }
                        if (_dragX.value.abs() >= width * 0.22) _resolve(side);
                      },
                      onHorizontalDragCancel: _returnCard,
                      onHorizontalDragEnd: (details) {
                        if (!_canClassify) return;
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 700) {
                          _resolve(
                            velocity < 0 ? SortSide.left : SortSide.right,
                          );
                        } else {
                          _returnCard();
                        }
                      },
                      child: RepaintBoundary(
                        child: AppCard(
                          variant: AppCardVariant.tinted,
                          tintColor: context.themeColors.primary,
                          elevationLevel: 0,
                          padding: AppSpacing.paddingLg,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.question.itemsInOrder[index],
                                textAlign: TextAlign.center,
                                style: context.appTextStyles.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.west_rounded,
                                    color: context.themeColors.primary,
                                    size: 18,
                                  ),
                                  Text(
                                    'Swipe',
                                    style: context.appTextStyles.labelSmall,
                                  ),
                                  Icon(
                                    Icons.east_rounded,
                                    color: context.themeColors.secondary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    builder: (context, child) {
                      final exiting = _phase == _SortPhase.exiting;
                      final t = AppMotion.easeOut.transform(
                        _exitController.value,
                      );
                      final offset = exiting
                          ? Offset.lerp(_exitStart, _exitTarget, t)!
                          : Offset(
                              _dragX.value +
                                  (_isDragging ? 0 : _exitStart.dx * (1 - t)),
                              _fallY,
                            );
                      return Transform.translate(
                        offset: offset,
                        child: Transform.rotate(
                          angle: _reducedMotion
                              ? 0
                              : (offset.dx / width).clamp(-0.12, 0.12) *
                                    (exiting ? 1 - t : 1),
                          child: Transform.scale(
                            scale: exiting && !_reducedMotion
                                ? 1 - 0.45 * t
                                : 1,
                            child: Opacity(
                              opacity: exiting ? 1 - t : 1,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_helpVisible)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.themeColors.background,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _revealedIndex == _currentItemIndex
                                  ? 'Correct group: ${widget.question.categoryLabel(widget.question.correctSides[_currentItemIndex])}'
                                  : widget.question.hint ??
                                        'Think about what each group represents before choosing a side.',
                              textAlign: TextAlign.center,
                              style: context.appTextStyles.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'Continue sorting',
                              onPressed: () {
                                setState(() => _helpVisible = false);
                                _resumeFall();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedback(BuildContext context, bool resolved) {
    final colors = context.themeColors;
    if (!resolved) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _helpVisible || _powerUpBusy ? 'Paused' : 'Swipe or tap a group',
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodyMedium,
          ),
          Text(
            '$_correctCount correct · ${_history.length - _correctCount} wrong',
            textAlign: TextAlign.center,
            style: context.appTextStyles.labelSmall,
          ),
        ],
      );
    }
    final missed = _history.last == null;
    final correct =
        _history.last == widget.question.correctSides[_currentItemIndex - 1];
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: correct ? colors.success : colors.error,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                missed
                    ? 'Missed'
                    : correct
                    ? 'Correct'
                    : 'Wrong',
                style: context.appTextStyles.labelLarge.copyWith(
                  color: correct ? colors.success : colors.error,
                ),
              ),
            ],
          ),
          if (!correct)
            Text(
              'Correct answer: ${widget.question.categoryLabel(widget.question.correctSides[_currentItemIndex - 1])}',
              textAlign: TextAlign.center,
              style: context.appTextStyles.bodyMedium,
            ),
        ],
      ),
    );
  }
}
