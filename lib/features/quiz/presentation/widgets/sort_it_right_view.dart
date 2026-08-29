import 'package:flutter/material.dart';

import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

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

class _SortItRightViewState extends State<SortItRightView> {
  late List<String> _pendingEntries;
  final List<String> _debitEntries = [];
  final List<String> _creditEntries = [];
  final List<_SortMove> _moveHistory = [];
  double _dragDx = 0;
  bool _isAnimating = false;

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
  }

  String? get _currentEntry =>
      _pendingEntries.isEmpty ? null : _pendingEntries.first;

  void _reset() {
    setState(() {
      _pendingEntries = List.of(widget.question.itemsInOrder);
      _debitEntries.clear();
      _creditEntries.clear();
      _moveHistory.clear();
      _dragDx = 0;
      _isAnimating = false;
    });
  }

  void _sortCurrentEntry(_SortBucket bucket) {
    if (_isAnimating) return;
    final entry = _currentEntry;
    if (entry == null) return;

    setState(() {
      _isAnimating = true;
      _pendingEntries.removeAt(0);
      switch (bucket) {
        case _SortBucket.debit:
          _debitEntries.add(entry);
        case _SortBucket.credit:
          _creditEntries.add(entry);
      }
      _moveHistory.add(_SortMove(entry: entry, bucket: bucket));
      _dragDx = 0;
    });

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _isAnimating = false);
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

  void _handleDragEnd() {
    if (_dragDx <= -100) {
      _sortCurrentEntry(_SortBucket.debit);
      return;
    }
    if (_dragDx >= 100) {
      _sortCurrentEntry(_SortBucket.credit);
      return;
    }
    setState(() => _dragDx = 0);
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
    final isCompact = screenHeight < 760;
    final displayCoins = widget.coins == 0 ? 120 : widget.coins;
    final displayEnergy = widget.energy == 0 ? 3 : widget.energy;
    final sortedCount = _debitEntries.length + _creditEntries.length;
    final totalEntries = widget.question.itemsInOrder.length;
    final displayStreak = widget.currentStreak == 0 ? 1 : widget.currentStreak;
    final canSubmit = _pendingEntries.isEmpty;

    return ColoredBox(
      color: _SortSwipeColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isCompact ? 6 : 8, 16, 0),
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
                onDragUpdate: (delta) {
                  if (_isAnimating) return;
                  setState(() {
                    _dragDx = (_dragDx + delta).clamp(-132.0, 132.0);
                  });
                },
                onDragEnd: _handleDragEnd,
                onDebitTap: () => _sortCurrentEntry(_SortBucket.debit),
                onCreditTap: () => _sortCurrentEntry(_SortBucket.credit),
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            _SortedPanels(
              debitEntries: _debitEntries,
              creditEntries: _creditEntries,
              isCompact: isCompact,
            ),
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
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDebitTap;
  final VoidCallback onCreditTap;

  const _SwipeStage({
    required this.currentEntry,
    required this.dragDx,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDebitTap,
    required this.onCreditTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = constraints.maxHeight;
        final cardHeight = (stageHeight * 0.72).clamp(156.0, 210.0);
        final cardWidth = (constraints.maxWidth * 0.86).clamp(280.0, 340.0);
        final top = ((stageHeight - cardHeight) / 2).clamp(0.0, 24.0);
        final sideOpacity = (dragDx.abs() / 100).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: top + cardHeight * 0.30,
              child: _DirectionHint(
                label: 'Debit',
                icon: Icons.arrow_back_rounded,
                opacity: dragDx < 0 ? sideOpacity : 0.20,
                onTap: onDebitTap,
              ),
            ),
            Positioned(
              right: 0,
              top: top + cardHeight * 0.30,
              child: _DirectionHint(
                label: 'Credit',
                icon: Icons.arrow_forward_rounded,
                opacity: dragDx > 0 ? sideOpacity : 0.20,
                onTap: onCreditTap,
              ),
            ),
            Positioned(
              top: top + 14,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: cardWidth * 0.82,
                  height: cardHeight * 0.86,
                  decoration: _SortSwipeDecoration.backCard(),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              left: (constraints.maxWidth - cardWidth) / 2 + dragDx,
              top: top,
              child: GestureDetector(
                key: const ValueKey('sort-swipe-card'),
                onHorizontalDragUpdate: (details) =>
                    onDragUpdate(details.delta.dx),
                onHorizontalDragEnd: (_) => onDragEnd(),
                child: Transform.rotate(
                  angle: dragDx / 1200,
                  child: _EntrySwipeCard(
                    entry: currentEntry,
                    width: cardWidth,
                    height: cardHeight,
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

  const _EntrySwipeCard({
    required this.entry,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _SortSwipeColors.greenSoft, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 26,
            offset: Offset(0, 16),
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
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: height < 180 ? 58 : 70,
                  height: height < 180 ? 58 : 70,
                  decoration: const BoxDecoration(
                    color: _SortSwipeColors.iconBubble,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    color: _SortSwipeColors.greenDark,
                    size: height < 180 ? 30 : 36,
                  ),
                ),
                SizedBox(height: height < 180 ? 12 : 16),
                SizedBox(
                  width: width * 0.78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _SortSwipeColors.textDark,
                        fontSize: height < 180 ? 22 : 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: height < 180 ? 8 : 12),
                Text(
                  'Account Entry',
                  style: TextStyle(
                    color: _SortSwipeColors.muted,
                    fontSize: height < 180 ? 14 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: height < 180 ? 14 : 18),
                Container(
                  width: 74,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _SortSwipeColors.dragHandle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 48,
                  height: 4,
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
  final double opacity;
  final VoidCallback onTap;

  const _DirectionHint({
    required this.label,
    required this.icon,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: opacity,
        child: Container(
          width: 78,
          height: 70,
          decoration: BoxDecoration(
            color: _SortSwipeColors.badgeFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _SortSwipeColors.badgeBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _SortSwipeColors.green, size: 27),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: _SortSwipeColors.greenDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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
        color: Colors.white,
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Positioned(
                right: 16,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
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
            color: Colors.white,
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
      color: Colors.white,
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
      color: Colors.white,
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

  static const Color green = Color(0xFF16B84E);
  static const Color greenDark = Color(0xFF05963E);
  static const Color greenSoft = Color(0xFF98E6B2);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color muted = Color(0xFF66708D);
  static const Color border = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x120F172A);
  static const Color coin = Color(0xFFF59E0B);
  static const Color energy = Color(0xFFF59E0B);
  static const Color greenTrack = Color(0xFFDFF3E8);
  static const Color disabled = Color(0xFFCBD5E1);
  static const Color disabledDark = Color(0xFF94A3B8);
  static const Color badgeFill = Color(0xFFEFFBF3);
  static const Color badgeBorder = Color(0xFFCBEFD6);
  static const Color scaleIcon = Color(0xFFB9C4D4);
  static const Color iconBubble = Color(0xFFE9F8EE);
  static const Color dragHandle = Color(0xFFD5DAE5);
  static const Color panelFill = Color(0xF7F6FEF8);
  static const Color handle = Color(0xFFB7C0CF);
}
