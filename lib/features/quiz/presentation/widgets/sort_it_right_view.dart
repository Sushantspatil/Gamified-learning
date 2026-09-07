import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../shared/widgets/app_choice_card.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';

class SortItRightView extends StatefulWidget {
  final SortItRightQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int coins;
  final int energy;
  final VoidCallback onExit;
  final void Function(Answer answer) onSubmit;

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
  });

  @override
  State<SortItRightView> createState() => _SortItRightViewState();
}

class _SortItRightViewState extends State<SortItRightView>
    with SingleTickerProviderStateMixin {
  // One choice per original item index, including duplicate item labels.
  // Progress and correctness are derived; undo removes exactly one choice.
  final List<SortSide> _history = [];
  late final AnimationController _swipeController;
  Animation<double> _swipeAnimation = const AlwaysStoppedAnimation(0);
  Timer? _feedbackTimer;
  double _dragDx = 0;
  bool _started = false;
  bool _isAnimating = false;
  bool _isDragging = false;
  bool _submitted = false;
  bool _powerUpBusy = false;
  bool _hintUsed = false;
  bool _revealUsed = false;
  int? _revealedIndex;
  bool? _feedbackCorrect;
  SortSide? _activeSide;

  int get _currentItemIndex => _history.length;
  bool get _complete =>
      _currentItemIndex >= widget.question.itemsInOrder.length;
  bool get _canClassify =>
      _started && !_complete && !_isAnimating && !_submitted && !_powerUpBusy;
  int get _correctCount => _history.indexed
      .where((move) => widget.question.correctSides[move.$1] == move.$2)
      .length;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this)
      ..addListener(() => setState(() => _dragDx = _swipeAnimation.value));
  }

  @override
  void didUpdateWidget(covariant SortItRightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _feedbackTimer?.cancel();
      _swipeController.stop();
      _history.clear();
      _dragDx = 0;
      _started = widget.currentIndex > 0;
      _isAnimating = false;
      _isDragging = false;
      _submitted = false;
      _hintUsed = false;
      _revealUsed = false;
      _revealedIndex = null;
      _feedbackCorrect = null;
      _activeSide = null;
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _swipeController.dispose();
    super.dispose();
  }

  Future<bool> _animateTo(double dx) async {
    if (AppMotion.reduceMotion(context)) {
      setState(() => _dragDx = dx);
      return true;
    }
    _swipeAnimation = Tween<double>(begin: _dragDx, end: dx).animate(
      CurvedAnimation(parent: _swipeController, curve: AppMotion.easeOut),
    );
    _swipeController.duration = AppMotion.normal;
    try {
      await _swipeController.forward(from: 0).orCancel;
      return mounted;
    } on TickerCanceled {
      return false;
    }
  }

  Future<void> _classify(SortSide side) async {
    if (!_canClassify) return;
    final index = _currentItemIndex;
    setState(() {
      _isAnimating = true;
      _isDragging = false;
      _activeSide = side;
    });
    // A viewport width clears the trailing corner of the tilted card.
    final exit =
        MediaQuery.sizeOf(context).width * (side == SortSide.left ? -1 : 1);
    if (!await _animateTo(exit)) return;
    setState(() {
      _history.add(side);
      _feedbackCorrect = side == widget.question.correctSides[index];
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      if (_complete) {
        setState(() => _submitted = true);
        widget.onSubmit(
          SortAnswer(
            questionId: widget.question.id,
            orderedItems: List.of(widget.question.itemsInOrder),
            selectedSides: List.unmodifiable(_history),
          ),
        );
      } else {
        setState(() {
          _dragDx = 0;
          _isAnimating = false;
          _activeSide = null;
          _feedbackCorrect = null;
        });
      }
    });
  }

  Future<void> _returnCard() async {
    if (!_canClassify) return;
    setState(() {
      _isAnimating = true;
      _isDragging = false;
      _activeSide = null;
    });
    if (await _animateTo(0)) setState(() => _isAnimating = false);
  }

  void _undo() {
    if (_history.isEmpty || _isAnimating || _submitted) return;
    setState(() {
      _history.removeLast();
      _dragDx = 0;
      _activeSide = null;
      _isDragging = false;
    });
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
    final displayIndex = _feedbackCorrect != null
        ? _currentItemIndex
        : (_currentItemIndex + 1).clamp(1, total);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const Key('sort-scroll'),
          padding: AppSpacing.paddingMd,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSpacing.md * 2).clamp(
                0,
                double.infinity,
              ),
            ),
            child: IntrinsicHeight(
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
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Classify each item into the correct group',
                    textAlign: TextAlign.center,
                    style: context.appTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final side in SortSide.values) ...[
                        if (side == SortSide.right)
                          const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppChoiceCard(
                            key: ValueKey(
                              side == SortSide.left
                                  ? 'sort-bucket-debit'
                                  : 'sort-bucket-credit',
                            ),
                            label: question.categoryLabel(side),
                            icon: side == SortSide.left
                                ? Icons.west_rounded
                                : Icons.east_rounded,
                            accentColor: side == SortSide.left
                                ? colors.primary
                                : colors.secondary,
                            selected:
                                _activeSide == side ||
                                (_revealedIndex == _currentItemIndex &&
                                    !_complete &&
                                    question.correctSides[_currentItemIndex] ==
                                        side),
                            onPressed: _canClassify
                                ? () => _classify(side)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_started) ...[
                    Icon(Icons.swipe_rounded, size: 48, color: colors.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '$total items. Two groups.',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Swipe left or right, or tap a group. You’ll see feedback after each item.',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Start sorting',
                      onPressed: () => setState(() => _started = true),
                    ),
                  ] else ...[
                    ClipRect(
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: _buildCard(context, constraints.maxWidth),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: _feedbackCorrect == null
                          ? Text(
                              'Swipe or tap a group',
                              textAlign: TextAlign.center,
                              style: context.appTextStyles.bodyMedium,
                            )
                          : Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _feedbackCorrect!
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,
                                      color: _feedbackCorrect!
                                          ? colors.success
                                          : colors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      _feedbackCorrect! ? 'Correct' : 'Wrong',
                                      style: context.appTextStyles.labelLarge
                                          .copyWith(
                                            color: _feedbackCorrect!
                                                ? colors.success
                                                : colors.error,
                                          ),
                                    ),
                                  ],
                                ),
                                if (!_feedbackCorrect!)
                                  Text(
                                    'Correct answer: ${question.categoryLabel(question.correctSides[_currentItemIndex - 1])}',
                                    textAlign: TextAlign.center,
                                    style: context.appTextStyles.bodyMedium,
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '$_correctCount correct · ${_history.length - _correctCount} wrong',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.labelSmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Spacer(),
                  if (_hintUsed) ...[
                    Text(
                      question.hint ??
                          'Think about what each group represents before choosing a side.',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_revealedIndex == _currentItemIndex && !_complete) ...[
                    Text(
                      'Correct group: ${question.categoryLabel(question.correctSides[_currentItemIndex])}',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  GamePowerUpBar(
                    onBusyChanged: (busy) =>
                        setState(() => _powerUpBusy = busy),
                    isDense: true,
                    showWallet: false,
                    isDisabled:
                        !_started || _isAnimating || _isDragging || _submitted,
                    actions: [
                      GamePowerUpAction(
                        id: 'sort-hint',
                        label: 'Hint',
                        description: 'Show a sorting strategy.',
                        coinCost: 10,
                        icon: Icons.lightbulb_outline,
                        isUsed: _hintUsed,
                        onUse: () => setState(() => _hintUsed = true),
                      ),
                      GamePowerUpAction(
                        id: 'sort-reveal',
                        label: 'Reveal',
                        description: 'Reveal the correct group for this card.',
                        coinCost: 25,
                        icon: Icons.visibility_outlined,
                        isUsed: _revealUsed,
                        isDisabled: _complete,
                        onUse: () => setState(() {
                          _revealUsed = true;
                          _revealedIndex = _currentItemIndex;
                        }),
                      ),
                      GamePowerUpAction(
                        id: 'sort-undo',
                        label: 'Undo',
                        description:
                            'Return to the previous item and undo its answer.',
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

  Widget _buildCard(BuildContext context, double width) {
    final index = _feedbackCorrect != null
        ? _currentItemIndex - 1
        : _currentItemIndex;
    if (index >= widget.question.itemsInOrder.length) {
      return const SizedBox.shrink();
    }
    final reduced = AppMotion.reduceMotion(context);
    return Transform.translate(
      offset: Offset(_dragDx, 0),
      child: Transform.rotate(
        angle: reduced ? 0 : (_dragDx / width).clamp(-0.16, 0.16),
        child: GestureDetector(
          key: const Key('sort-active-card'),
          onHorizontalDragUpdate: (details) {
            if (!_canClassify) return;
            setState(() {
              _dragDx = (_dragDx + details.delta.dx).clamp(-width, width);
              _isDragging = true;
              _activeSide = _dragDx == 0
                  ? null
                  : _dragDx < 0
                  ? SortSide.left
                  : SortSide.right;
            });
          },
          onHorizontalDragCancel: _returnCard,
          onHorizontalDragEnd: (details) {
            if (!_canClassify) return;
            final velocity = details.primaryVelocity ?? 0;
            if (_dragDx.abs() >= width * 0.22 || velocity.abs() > 700) {
              final direction = _dragDx.abs() >= width * 0.22
                  ? _dragDx
                  : velocity;
              _classify(direction < 0 ? SortSide.left : SortSide.right);
            } else {
              _returnCard();
            }
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey('sort-item-$index'),
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.duration(context, AppMotion.fast),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : 12 * (1 - value)),
                child: child,
              ),
            ),
            child: SizedBox(
              width: (width - AppSpacing.md * 2).clamp(0, 360),
              child: AppCard(
                variant: AppCardVariant.tinted,
                tintColor: context.themeColors.primary,
                elevationLevel: 0,
                padding: AppSpacing.paddingLg,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 144),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.question.itemsInOrder[index],
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.west_rounded,
                            color: context.themeColors.primary,
                          ),
                          Text(
                            'Swipe',
                            style: context.appTextStyles.labelSmall,
                          ),
                          Icon(
                            Icons.east_rounded,
                            color: context.themeColors.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
