import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';

enum _SortBucket { debit, credit }

class _SortMove {
  final String entry;
  final _SortBucket bucket;

  const _SortMove({required this.entry, required this.bucket});
}

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
  late List<String> _pendingEntries;
  final List<String> _debitEntries = [];
  final List<String> _creditEntries = [];
  final List<_SortMove> _moveHistory = [];
  late final AnimationController _swipeController;
  Animation<double> _swipeAnimation = const AlwaysStoppedAnimation(0);
  double _dragDx = 0;
  bool _isAnimating = false;
  bool _isDragging = false;
  bool _hintUsed = false;
  bool _revealSideUsed = false;
  _SortBucket? _activeBucket;

  static const Set<String> _correctDebitEntries = {
    'Purchase',
    'Salary Paid',
    'Discount Allowed',
  };
  static const Set<String> _correctCreditEntries = {
    'Cash Received',
    'Sales Revenue',
  };

  @override
  void initState() {
    super.initState();
    _pendingEntries = List.of(widget.question.itemsInOrder);
    _swipeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (mounted) {
            setState(() => _dragDx = _swipeAnimation.value);
          }
        });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  String? get _currentEntry =>
      _pendingEntries.isEmpty ? null : _pendingEntries.first;

  void _reset() {
    _swipeController.stop();
    setState(() {
      _pendingEntries = List.of(widget.question.itemsInOrder);
      _debitEntries.clear();
      _creditEntries.clear();
      _moveHistory.clear();
      _dragDx = 0;
      _isAnimating = false;
      _isDragging = false;
      _hintUsed = false;
      _revealSideUsed = false;
      _activeBucket = null;
    });
  }

  Future<void> _animateCardTo(
    double targetDx, {
    required Duration duration,
    required Curve curve,
  }) async {
    _swipeAnimation = Tween<double>(
      begin: _dragDx,
      end: targetDx,
    ).animate(CurvedAnimation(parent: _swipeController, curve: curve));
    _swipeController
      ..duration = duration
      ..reset();
    await _swipeController.forward();
  }

  Future<void> _sortCurrentEntry(_SortBucket bucket, double exitDx) async {
    if (_isAnimating) return;
    final entry = _currentEntry;
    if (entry == null) return;

    setState(() {
      _isAnimating = true;
      _isDragging = false;
      _activeBucket = bucket;
    });

    await _animateCardTo(
      exitDx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInCubic,
    );
    if (!mounted) return;

    setState(() {
      switch (bucket) {
        case _SortBucket.debit:
          _debitEntries.add(entry);
        case _SortBucket.credit:
          _creditEntries.add(entry);
      }
      _moveHistory.add(_SortMove(entry: entry, bucket: bucket));
      _pendingEntries.removeAt(0);
      _dragDx = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _isAnimating = false;
      _activeBucket = null;
    });
  }

  void _undo() {
    if (_moveHistory.isEmpty || _isAnimating) return;
    final lastMove = _moveHistory.removeLast();
    setState(() {
      switch (lastMove.bucket) {
        case _SortBucket.debit:
          _debitEntries.remove(lastMove.entry);
        case _SortBucket.credit:
          _creditEntries.remove(lastMove.entry);
      }
      _pendingEntries.insert(0, lastMove.entry);
      _dragDx = 0;
    });
  }

  void _showHint() {
    if (_hintUsed) return;
    setState(() => _hintUsed = true);
  }

  void _revealCurrentSide() {
    if (_revealSideUsed) return;
    final entry = _currentEntry;
    if (entry == null) return;

    final bucket = _correctDebitEntries.contains(entry) ? 'Debit' : 'Credit';
    setState(() => _revealSideUsed = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$entry belongs under $bucket.')));
  }

  Future<void> _handleDragEnd(_SortBucket? bucket, double exitDx) async {
    if (_isAnimating) return;
    if (bucket != null) {
      await _sortCurrentEntry(bucket, exitDx);
      return;
    }

    setState(() {
      _isDragging = false;
      _activeBucket = null;
    });
    await _animateCardTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
    );
  }

  void _submit() {
    final isComplete = _pendingEntries.isEmpty;
    final isCorrect =
        _debitEntries.toSet().containsAll(_correctDebitEntries) &&
        _correctDebitEntries.containsAll(_debitEntries) &&
        _creditEntries.toSet().containsAll(_correctCreditEntries) &&
        _correctCreditEntries.containsAll(_creditEntries);

    if (!isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sort all entries before submitting.')),
      );
      return;
    }

    if (!isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some entries are incorrectly sorted. Try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Great job! Sorting is correct. +10 XP earned.'),
      ),
    );
    widget.onSubmit(
      SortAnswer(
        questionId: widget.question.id,
        orderedItems: [..._debitEntries, ..._creditEntries],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 900;
    final displayCoins = widget.coins == 0 ? 120 : widget.coins;
    final displayEnergy = widget.energy == 0 ? 3 : widget.energy;
    final sortedCount = _debitEntries.length + _creditEntries.length;
    final totalEntries = widget.question.itemsInOrder.length;
    final displayStreak = widget.currentStreak == 0 ? 1 : widget.currentStreak;
    final canSubmit = _pendingEntries.isEmpty;

    return ColoredBox(
      color: _SortSwipeColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          isCompact ? 6 : 8,
          AppSpacing.screenPadding,
          0,
        ),
        child: Column(
          children: [
            _SortTopBar(
              coins: displayCoins,
              energy: displayEnergy,
              onBack: widget.onExit,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 10),
            _ProgressCard(
              currentQuestion: sortedCount + 1 > totalEntries
                  ? totalEntries
                  : sortedCount + 1,
              totalQuestions: totalEntries,
              streak: displayStreak,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 10),
            _QuestionCard(question: widget.question, isCompact: isCompact),
            SizedBox(height: isCompact ? 8 : 10),
            _SwipeHintBar(isCompact: isCompact),
            SizedBox(height: isCompact ? 6 : 8),
            Expanded(
              child: _SwipeStage(
                currentEntry: _currentEntry,
                dragDx: _dragDx,
                isAnimating: _isAnimating,
                isDragging: _isDragging,
                activeBucket: _activeBucket,
                onDragUpdate: (delta, maxDragDx) {
                  if (_isAnimating) return;
                  setState(() {
                    final nextDx = _dragDx + delta;
                    _isDragging = true;
                    _activeBucket = nextDx < 0
                        ? _SortBucket.debit
                        : nextDx > 0
                        ? _SortBucket.credit
                        : null;
                    _dragDx = nextDx.clamp(-maxDragDx, maxDragDx);
                  });
                },
                onDragEnd: _handleDragEnd,
                onBucketTap: (bucket, exitDx) =>
                    _sortCurrentEntry(bucket, exitDx),
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            _SortedPanels(
              debitEntries: _debitEntries,
              creditEntries: _creditEntries,
              isCompact: isCompact,
            ),
            SizedBox(height: isCompact ? 8 : 10),
            GamePowerUpBar(
              coinBalanceOverride: widget.coins,
              isDense: true,
              showWallet: false,
              actions: [
                GamePowerUpAction(
                  id: 'sort-hint',
                  label: 'Hint',
                  description: 'Show a sorting strategy.',
                  coinCost: 10,
                  icon: Icons.lightbulb_outline,
                  isUsed: _hintUsed,
                  onUse: _showHint,
                ),
                GamePowerUpAction(
                  id: 'sort-reveal',
                  label: 'Reveal',
                  description: 'Reveal the correct side for this card.',
                  coinCost: 25,
                  icon: Icons.visibility_outlined,
                  isUsed: _revealSideUsed,
                  isDisabled: _currentEntry == null,
                  onUse: _revealCurrentSide,
                ),
                GamePowerUpAction(
                  id: 'sort-undo',
                  label: 'Undo',
                  description: 'Undo the last sorted card.',
                  coinCost: 10,
                  icon: Icons.undo_rounded,
                  isDisabled: _moveHistory.isEmpty,
                  onUse: _undo,
                ),
              ],
            ),
            if (_hintUsed) ...[
              SizedBox(height: isCompact ? 7 : 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _SortSwipeColors.badgeFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _SortSwipeColors.badgeBorder),
                ),
                child: const Text(
                  'Assets and expenses usually increase on Debit. Income and cash received usually increase on Credit.',
                  style: TextStyle(
                    color: _SortSwipeColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            SizedBox(height: isCompact ? 8 : 10),
            _BottomActions(
              canSubmit: canSubmit,
              onReset: _reset,
              onUndo: _undo,
              onSubmit: _submit,
              isCompact: isCompact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortTopBar extends StatelessWidget {
  final int coins;
  final int energy;
  final VoidCallback onBack;
  final bool isCompact;

  const _SortTopBar({
    required this.coins,
    required this.energy,
    required this.onBack,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isCompact ? 56 : 62,
      child: Row(
        children: [
          _SoftIconButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Sort It Out',
                      maxLines: 1,
                      style: TextStyle(
                        color: _SortSwipeColors.textDark,
                        fontSize: isCompact ? 20 : 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Swipe to sort',
                      maxLines: 1,
                      style: TextStyle(
                        color: _SortSwipeColors.muted,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatChip(
                icon: Icons.monetization_on_rounded,
                value: coins.toString(),
                iconColor: _SortSwipeColors.coin,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.bolt_rounded,
                value: energy.toString(),
                iconColor: _SortSwipeColors.energy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color iconColor;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: _SortSwipeDecoration.card(radius: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: _SortSwipeColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int streak;
  final bool isCompact;

  const _ProgressCard({
    required this.currentQuestion,
    required this.totalQuestions,
    required this.streak,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions == 0
        ? 0.0
        : currentQuestion / totalQuestions;
    final percent = (progress * 100).round();

    return Container(
      height: isCompact ? 104 : 108,
      padding: EdgeInsets.fromLTRB(16, isCompact ? 10 : 12, 16, 10),
      decoration: _SortSwipeDecoration.card(radius: 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question',
                      style: TextStyle(
                        color: _SortSwipeColors.muted,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: isCompact ? 5 : 7),
                    Text(
                      '$currentQuestion / $totalQuestions',
                      style: TextStyle(
                        color: _SortSwipeColors.textDark,
                        fontSize: isCompact ? 27 : 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Streak',
                    style: TextStyle(
                      color: _SortSwipeColors.muted,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: isCompact ? 6 : 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.deepOrangeAccent.shade200,
                        size: isCompact ? 22 : 24,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        streak.toString(),
                        style: TextStyle(
                          color: _SortSwipeColors.textDark,
                          fontSize: isCompact ? 23 : 25,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: isCompact ? 8 : 9,
                    color: _SortSwipeColors.green,
                    backgroundColor: _SortSwipeColors.greenTrack,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Text(
                '$percent%',
                style: TextStyle(
                  color: _SortSwipeColors.green,
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final SortItRightQuestion question;
  final bool isCompact;

  const _QuestionCard({required this.question, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 112 : 124,
      padding: EdgeInsets.fromLTRB(16, isCompact ? 12 : 14, 16, 12),
      decoration: _SortSwipeDecoration.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const _ModeBadge(
                icon: Icons.star_border_rounded,
                label: 'Challenge',
              ),
              _ModeBadge(label: '+${question.points} XP'),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: isCompact ? 72 : 86),
                  child: Text(
                    question.prompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _SortSwipeColors.textDark,
                      fontSize: isCompact ? 17 : 19,
                      fontWeight: FontWeight.w900,
                      height: 1.28,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 0,
                  child: Icon(
                    Icons.balance_rounded,
                    color: _SortSwipeColors.scaleIcon,
                    size: isCompact ? 58 : 66,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeHintBar extends StatelessWidget {
  final bool isCompact;

  const _SwipeHintBar({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isCompact ? 44 : 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _SortSwipeDecoration.card(radius: 18),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            Icon(
              Icons.arrow_back_rounded,
              color: _SortSwipeColors.green,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Debit',
              style: TextStyle(
                color: _SortSwipeColors.green,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 26),
            Text(
              'Swipe the card',
              style: TextStyle(
                color: _SortSwipeColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 26),
            Text(
              'Credit',
              style: TextStyle(
                color: _SortSwipeColors.green,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              color: _SortSwipeColors.green,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeStage extends StatelessWidget {
  final String? currentEntry;
  final double dragDx;
  final bool isAnimating;
  final bool isDragging;
  final _SortBucket? activeBucket;
  final void Function(double delta, double maxDragDx) onDragUpdate;
  final void Function(_SortBucket? bucket, double exitDx) onDragEnd;
  final void Function(_SortBucket bucket, double exitDx) onBucketTap;

  const _SwipeStage({
    required this.currentEntry,
    required this.dragDx,
    required this.isAnimating,
    required this.isDragging,
    required this.activeBucket,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBucketTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = constraints.maxHeight;
        final cardHeight = (stageHeight * 0.58).clamp(104.0, 170.0);
        final cardWidth = (constraints.maxWidth * 0.78).clamp(250.0, 320.0);
        final top = ((stageHeight - cardHeight) / 2).clamp(6.0, 22.0);
        final threshold = constraints.maxWidth * 0.28;
        final maxDragDx = constraints.maxWidth * 0.48;
        final exitDx = constraints.maxWidth + cardWidth;
        final progress = (dragDx.abs() / threshold).clamp(0.0, 1.0);
        final acceptedBucket = dragDx <= -threshold
            ? _SortBucket.debit
            : dragDx >= threshold
            ? _SortBucket.credit
            : null;
        final cardScale = isAnimating && activeBucket != null ? 0.90 : 1.0;
        final nextCardScale = isAnimating && activeBucket != null ? 0.98 : 0.94;
        final nextCardOpacity = currentEntry == null ? 0.0 : 0.55;
        final rotation = (dragDx / constraints.maxWidth).clamp(-0.11, 0.11);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: top + cardHeight * 0.30,
              child: _DirectionHint(
                key: const ValueKey('sort-bucket-debit'),
                label: 'Debit',
                icon: Icons.arrow_back_rounded,
                progress: dragDx < 0 || activeBucket == _SortBucket.debit
                    ? progress
                    : 0,
                isPulsing: isAnimating && activeBucket == _SortBucket.debit,
                onTap: () => onBucketTap(_SortBucket.debit, -exitDx),
              ),
            ),
            Positioned(
              right: 0,
              top: top + cardHeight * 0.30,
              child: _DirectionHint(
                key: const ValueKey('sort-bucket-credit'),
                label: 'Credit',
                icon: Icons.arrow_forward_rounded,
                progress: dragDx > 0 || activeBucket == _SortBucket.credit
                    ? progress
                    : 0,
                isPulsing: isAnimating && activeBucket == _SortBucket.credit,
                onTap: () => onBucketTap(_SortBucket.credit, exitDx),
              ),
            ),
            Positioned(
              top: top + 13,
              child: AnimatedScale(
                scale: nextCardScale,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: nextCardOpacity,
                  duration: const Duration(milliseconds: 140),
                  child: Transform.rotate(
                    angle: -0.035,
                    child: Container(
                      width: cardWidth * 0.92,
                      height: cardHeight * 0.90,
                      decoration: _SortSwipeDecoration.backCard(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: (constraints.maxWidth - cardWidth) / 2,
              top: top,
              child: Transform.translate(
                offset: Offset(dragDx, 0),
                child: AnimatedScale(
                  scale: cardScale,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    key: const ValueKey('sort-swipe-card'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: currentEntry == null || isAnimating
                        ? null
                        : (details) =>
                              onDragUpdate(details.delta.dx, maxDragDx),
                    onHorizontalDragEnd: currentEntry == null || isAnimating
                        ? null
                        : (_) => onDragEnd(
                            acceptedBucket,
                            acceptedBucket == _SortBucket.debit
                                ? -exitDx
                                : exitDx,
                          ),
                    child: Transform.rotate(
                      angle: rotation,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeOut,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.94,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _EntrySwipeCard(
                          key: ValueKey(currentEntry ?? 'complete-card'),
                          entry: currentEntry,
                          width: cardWidth,
                          height: cardHeight,
                          isActive: isDragging || isAnimating,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EntrySwipeCard extends StatelessWidget {
  final String? entry;
  final double width;
  final double height;
  final bool isActive;

  const _EntrySwipeCard({
    super.key,
    required this.entry,
    required this.width,
    required this.height,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height * 0.86, maxHeight: height),
      padding: EdgeInsets.symmetric(
        horizontal: height < 150 ? 14 : 18,
        vertical: height < 150 ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: _SortSwipeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? _SortSwipeColors.green : _SortSwipeColors.greenSoft,
          width: isActive ? 1.7 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x220F172A),
            blurRadius: isActive ? 30 : 22,
            offset: Offset(0, isActive ? 18 : 12),
          ),
        ],
      ),
      child: entry == null
          ? const Center(
              child: Text(
                'All entries sorted',
                style: TextStyle(
                  color: _SortSwipeColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : height < 120
          ? Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: _SortSwipeColors.iconBubble,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: _SortSwipeColors.greenDark,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SortSwipeColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _SortSwipeColors.dragHandle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: height < 150 ? 40 : 58,
                  height: height < 150 ? 40 : 58,
                  decoration: const BoxDecoration(
                    color: _SortSwipeColors.iconBubble,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    color: _SortSwipeColors.greenDark,
                    size: height < 150 ? 22 : 31,
                  ),
                ),
                SizedBox(height: height < 150 ? 5 : 12),
                SizedBox(
                  width: width * 0.82,
                  child: Text(
                    entry!,
                    maxLines: height < 150 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _SortSwipeColors.textDark,
                      fontSize: height < 150 ? 16 : 23,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                ),
                SizedBox(height: height < 150 ? 3 : 8),
                Text(
                  'Account Entry',
                  style: TextStyle(
                    color: _SortSwipeColors.muted,
                    fontSize: height < 150 ? 11 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: height < 150 ? 5 : 12),
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _SortSwipeColors.dragHandle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _SortSwipeColors.dragHandle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DirectionHint extends StatelessWidget {
  final String label;
  final IconData icon;
  final double progress;
  final bool isPulsing;
  final VoidCallback onTap;

  const _DirectionHint({
    super.key,
    required this.label,
    required this.icon,
    required this.progress,
    required this.isPulsing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final intensity = progress.clamp(0.0, 1.0);
    final scale = isPulsing ? 1.12 : 1 + (intensity * 0.08);
    final opacity = 0.22 + (intensity * 0.78);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        curve: isPulsing ? Curves.elasticOut : Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: opacity,
          child: Container(
            width: 78,
            height: 70,
            decoration: BoxDecoration(
              color: Color.lerp(
                _SortSwipeColors.badgeFill,
                _SortSwipeColors.bucketActiveFill,
                intensity,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color.lerp(
                  _SortSwipeColors.badgeBorder,
                  _SortSwipeColors.green,
                  intensity,
                )!,
                width: 1.2 + intensity * 0.8,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: _SortSwipeColors.green, size: 25),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _SortSwipeColors.greenDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortedPanels extends StatelessWidget {
  final List<String> debitEntries;
  final List<String> creditEntries;
  final bool isCompact;

  const _SortedPanels({
    required this.debitEntries,
    required this.creditEntries,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SortedBucketPanel(
            title: 'Debit',
            count: debitEntries.length,
            entries: debitEntries,
            leadingIcon: Icons.arrow_back_rounded,
            isCompact: isCompact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SortedBucketPanel(
            title: 'Credit',
            count: creditEntries.length,
            entries: creditEntries,
            leadingIcon: Icons.arrow_forward_rounded,
            alignEnd: true,
            isCompact: isCompact,
          ),
        ),
      ],
    );
  }
}

class _SortedBucketPanel extends StatelessWidget {
  final String title;
  final int count;
  final List<String> entries;
  final IconData leadingIcon;
  final bool alignEnd;
  final bool isCompact;

  const _SortedBucketPanel({
    required this.title,
    required this.count,
    required this.entries,
    required this.leadingIcon,
    required this.isCompact,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: _SortSwipeColors.green, radius: 18),
      child: Container(
        height: isCompact ? 106 : 122,
        padding: EdgeInsets.fromLTRB(9, isCompact ? 8 : 10, 9, 9),
        decoration: BoxDecoration(
          color: _SortSwipeColors.panelFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (!alignEnd) _CircleIcon(icon: leadingIcon, onTap: null),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _SortSwipeColors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _CountPill(count: count),
                      ],
                    ),
                  ),
                ),
                if (alignEnd) _CircleIcon(icon: leadingIcon, onTap: null),
              ],
            ),
            SizedBox(height: isCompact ? 7 : 9),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        'No entries yet',
                        style: TextStyle(
                          color: _SortSwipeColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) =>
                          _SortedEntryTile(entry: entries[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortedEntryTile extends StatelessWidget {
  final String entry;

  const _SortedEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _SortSwipeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SortSwipeColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: const BoxDecoration(
              color: _SortSwipeColors.iconBubble,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _SortSwipeColors.green,
              size: 17,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              entry,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _SortSwipeColors.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            Icons.drag_indicator_rounded,
            color: _SortSwipeColors.handle,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool canSubmit;
  final VoidCallback onReset;
  final VoidCallback onUndo;
  final VoidCallback onSubmit;
  final bool isCompact;

  const _BottomActions({
    required this.canSubmit,
    required this.onReset,
    required this.onUndo,
    required this.onSubmit,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ResetButton(onPressed: onReset, isCompact: isCompact),
              const SizedBox(width: 10),
              _UndoButton(onPressed: onUndo, isCompact: isCompact),
              const SizedBox(width: 10),
              Expanded(
                child: _SubmitButton(
                  onPressed: canSubmit ? onSubmit : null,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 7 : 9),
          const Text(
            'Swipe left for Debit, right for Credit',
            style: TextStyle(
              color: _SortSwipeColors.greenDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isCompact;

  const _SubmitButton({required this.onPressed, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('sort-submit-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: isCompact ? 54 : 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [_SortSwipeColors.green, _SortSwipeColors.greenDark]
                  : const [
                      _SortSwipeColors.disabled,
                      _SortSwipeColors.disabledDark,
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x3322C55E),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Submit Sort',
                maxLines: 1,
                style: TextStyle(
                  color: _SortSwipeColors.buttonForeground,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Positioned(
                right: 16,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: _SortSwipeColors.buttonForeground,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isCompact;

  const _ResetButton({required this.onPressed, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: isCompact ? 58 : 62,
          height: isCompact ? 60 : 62,
          decoration: _SortSwipeDecoration.card(radius: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sync_rounded,
                color: _SortSwipeColors.green,
                size: isCompact ? 22 : 24,
              ),
              const SizedBox(height: 2),
              const Text(
                'Reset',
                style: TextStyle(
                  color: _SortSwipeColors.textDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isCompact;

  const _UndoButton({required this.onPressed, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: isCompact ? 48 : 52,
          height: isCompact ? 54 : 56,
          decoration: _SortSwipeDecoration.card(radius: 16),
          child: Icon(
            Icons.undo_rounded,
            color: _SortSwipeColors.muted,
            size: isCompact ? 23 : 25,
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _ModeBadge({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _SortSwipeColors.badgeFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _SortSwipeColors.badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _SortSwipeColors.green, size: 20),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _SortSwipeColors.greenDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SoftIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 50,
          height: 50,
          decoration: _SortSwipeDecoration.card(radius: 18),
          child: Icon(icon, color: _SortSwipeColors.textDark, size: 26),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _SortSwipeColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: _SortSwipeColors.greenSoft),
          ),
          child: Icon(icon, color: _SortSwipeColors.green, size: 21),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _SortSwipeColors.iconBubble,
        shape: BoxShape.circle,
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: _SortSwipeColors.greenDark,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 6.0;
      const dashSpace = 5.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _SortSwipeDecoration {
  _SortSwipeDecoration._();

  static BoxDecoration card({required double radius}) {
    return BoxDecoration(
      color: _SortSwipeColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _SortSwipeColors.border),
      boxShadow: const [
        BoxShadow(
          color: _SortSwipeColors.shadow,
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration backCard() {
    return BoxDecoration(
      color: _SortSwipeColors.surface,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _SortSwipeColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x180F172A),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

class _SortSwipeColors {
  _SortSwipeColors._();

  static const Color green = Color(0xFF5FE7FF);
  static const Color greenDark = Color(0xFF9D8CFF);
  static const Color greenSoft = Color(0xFF465078);
  static const Color background = Color(0xFF090B18);
  static const Color surface = Color(0xFF171B31);
  static const Color surfaceElevated = Color(0xFF222845);
  static const Color textDark = Color(0xFFF8FAFF);
  static const Color muted = Color(0xFFC7CDE3);
  static const Color border = Color(0xFF465078);
  static const Color shadow = Color(0x66000000);
  static const Color coin = Color(0xFFFFB82E);
  static const Color energy = Color(0xFF21E6FF);
  static const Color greenTrack = Color(0xFF2A3153);
  static const Color disabled = Color(0xFF2A3153);
  static const Color disabledDark = Color(0xFF465078);
  static const Color badgeFill = Color(0xFF222845);
  static const Color badgeBorder = Color(0xFF465078);
  static const Color bucketActiveFill = Color(0xFF243F57);
  static const Color scaleIcon = Color(0xFF9D8CFF);
  static const Color iconBubble = Color(0xFF2A3153);
  static const Color dragHandle = Color(0xFF5B668F);
  static const Color panelFill = Color(0xFF11162B);
  static const Color handle = Color(0xFF9AA3C0);
  static const Color buttonForeground = Color(0xFF090B18);
}
