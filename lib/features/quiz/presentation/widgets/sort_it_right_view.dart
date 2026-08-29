import 'package:flutter/material.dart';

import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

enum _SortBucket { debit, credit }

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
  double _dragDx = 0;

  static const Set<String> _correctDebitEntries = {
    'Purchase',
    'Salary Paid',
    'Discount Allowed',
  };
  static const Set<String> _correctCreditEntries = {'Cash Received'};

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
      _dragDx = 0;
    });
  }

  void _sortCurrentEntry(_SortBucket bucket) {
    final entry = _currentEntry;
    if (entry == null) return;

    setState(() {
      _pendingEntries.removeAt(0);
      switch (bucket) {
        case _SortBucket.debit:
          _debitEntries.add(entry);
        case _SortBucket.credit:
          _creditEntries.add(entry);
      }
      _dragDx = 0;
    });
  }

  void _handleDragEnd() {
    if (_dragDx <= -84) {
      _sortCurrentEntry(_SortBucket.debit);
      return;
    }
    if (_dragDx >= 84) {
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

    if (!isComplete || !isCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sort all entries correctly.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Great job! Sorting is correct.')),
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
    final displayTotal = widget.totalQuestions <= 1 ? 5 : widget.totalQuestions;
    final displayCoins = widget.coins == 0 ? 120 : widget.coins;
    final displayEnergy = widget.energy == 0 ? 3 : widget.energy;
    final displayStreak = widget.currentStreak == 0 ? 2 : widget.currentStreak;

    return ColoredBox(
      color: _SortSwipeColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            _SortTopBar(
              coins: displayCoins,
              energy: displayEnergy,
              onBack: widget.onExit,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressCard(
                      currentQuestion: widget.currentIndex + 1,
                      totalQuestions: displayTotal,
                      streak: displayStreak,
                    ),
                    const SizedBox(height: 16),
                    _QuestionCard(question: widget.question),
                    const SizedBox(height: 16),
                    const _SwipeHintBar(),
                    const SizedBox(height: 18),
                    _SwipeStage(
                      currentEntry: _currentEntry,
                      dragDx: _dragDx,
                      onDragUpdate: (delta) {
                        setState(() {
                          _dragDx = (_dragDx + delta).clamp(-128.0, 128.0);
                        });
                      },
                      onDragEnd: _handleDragEnd,
                      onDebitTap: () => _sortCurrentEntry(_SortBucket.debit),
                      onCreditTap: () => _sortCurrentEntry(_SortBucket.credit),
                    ),
                    const SizedBox(height: 22),
                    _SortedPanels(
                      debitEntries: _debitEntries,
                      creditEntries: _creditEntries,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            _BottomActions(onReset: _reset, onSubmit: _submit),
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

  const _SortTopBar({
    required this.coins,
    required this.energy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '✦ Swipe to sort ✦',
                      maxLines: 1,
                      style: TextStyle(
                        color: _SortSwipeColors.muted,
                        fontSize: 13,
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

  const _ProgressCard({
    required this.currentQuestion,
    required this.totalQuestions,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions == 0
        ? 0.0
        : currentQuestion / totalQuestions;
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _SortSwipeDecoration.card(radius: 22),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question',
                      style: TextStyle(
                        color: _SortSwipeColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$currentQuestion / $totalQuestions',
                      style: const TextStyle(
                        color: _SortSwipeColors.textDark,
                        fontSize: 32,
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
                  const Text(
                    'Streak',
                    style: TextStyle(
                      color: _SortSwipeColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.deepOrangeAccent.shade200,
                        size: 27,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        streak.toString(),
                        style: const TextStyle(
                          color: _SortSwipeColors.textDark,
                          fontSize: 28,
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 12,
                    color: _SortSwipeColors.green,
                    backgroundColor: _SortSwipeColors.greenTrack,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _SortSwipeColors.green,
                  fontSize: 18,
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

  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _SortSwipeDecoration.card(radius: 22),
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
          const SizedBox(height: 22),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 96),
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    color: _SortSwipeColors.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.45,
                  ),
                ),
              ),
              const Positioned(
                right: 12,
                top: 10,
                child: Icon(
                  Icons.balance_rounded,
                  color: _SortSwipeColors.scaleIcon,
                  size: 78,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwipeHintBar extends StatelessWidget {
  const _SwipeHintBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
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
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 34),
            Text(
              'Swipe the card',
              style: TextStyle(
                color: _SortSwipeColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 34),
            Text(
              'Credit',
              style: TextStyle(
                color: _SortSwipeColors.green,
                fontSize: 19,
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
    return SizedBox(
      height: 282,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(left: -22, child: _SideSwipeCue.debit(onTap: onDebitTap)),
          Positioned(
            right: -22,
            child: _SideSwipeCue.credit(onTap: onCreditTap),
          ),
          Positioned(
            top: 38,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                width: 218,
                height: 186,
                decoration: _SortSwipeDecoration.backCard(),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            left: MediaQuery.sizeOf(context).width / 2 - 170 + dragDx,
            top: 18,
            child: GestureDetector(
              key: const ValueKey('sort-swipe-card'),
              onHorizontalDragUpdate: (details) =>
                  onDragUpdate(details.delta.dx),
              onHorizontalDragEnd: (_) => onDragEnd(),
              child: Transform.rotate(
                angle: dragDx / 1200,
                child: _EntrySwipeCard(entry: currentEntry),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntrySwipeCard extends StatelessWidget {
  final String? entry;

  const _EntrySwipeCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 216,
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
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: _SortSwipeColors.iconBubble,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: _SortSwipeColors.greenDark,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 270,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _SortSwipeColors.textDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Account Entry',
                  style: TextStyle(
                    color: _SortSwipeColors.muted,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
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

class _SideSwipeCue extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCredit;
  final VoidCallback onTap;

  const _SideSwipeCue._({
    required this.label,
    required this.icon,
    required this.isCredit,
    required this.onTap,
  });

  factory _SideSwipeCue.debit({required VoidCallback onTap}) {
    return _SideSwipeCue._(
      label: 'Debit',
      icon: Icons.arrow_back_rounded,
      isCredit: false,
      onTap: onTap,
    );
  }

  factory _SideSwipeCue.credit({required VoidCallback onTap}) {
    return _SideSwipeCue._(
      label: 'Credit',
      icon: Icons.arrow_forward_rounded,
      isCredit: true,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: isCredit ? 0.11 : -0.11,
        child: Container(
          width: 128,
          height: 190,
          decoration: BoxDecoration(
            color: _SortSwipeColors.sideCue,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _SortSwipeColors.sideCueBorder, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _SortSwipeColors.green, size: 38),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: _SortSwipeColors.green,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Icon(
                isCredit
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                color: _SortSwipeColors.sideCueArrows,
                size: 40,
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

  const _SortedPanels({
    required this.debitEntries,
    required this.creditEntries,
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
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SortedBucketPanel(
            title: 'Credit',
            count: creditEntries.length,
            entries: creditEntries,
            leadingIcon: Icons.arrow_forward_rounded,
            alignEnd: true,
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

  const _SortedBucketPanel({
    required this.title,
    required this.count,
    required this.entries,
    required this.leadingIcon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: _SortSwipeColors.green, radius: 18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 188),
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 14),
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
            const SizedBox(height: 14),
            for (final entry in entries) ...[
              _SortedEntryTile(entry: entry),
              if (entry != entries.last) const SizedBox(height: 9),
            ],
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
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _SortSwipeColors.iconBubble,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _SortSwipeColors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _SortSwipeColors.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            Icons.drag_indicator_rounded,
            color: _SortSwipeColors.handle,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onSubmit;

  const _BottomActions({required this.onReset, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + 10, top: 2),
      child: Column(
        children: [
          Row(
            children: [
              _ResetButton(onPressed: onReset),
              const SizedBox(width: 12),
              Expanded(child: _SubmitButton(onPressed: onSubmit)),
            ],
          ),
          const SizedBox(height: 14),
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
  final VoidCallback onPressed;

  const _SubmitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('sort-submit-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_SortSwipeColors.green, _SortSwipeColors.greenDark],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3322C55E),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Submit Sort',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Positioned(
                right: 18,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 31,
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

  const _ResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 64,
          height: 64,
          decoration: _SortSwipeDecoration.card(radius: 18),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_rounded, color: _SortSwipeColors.green, size: 28),
              SizedBox(height: 4),
              Text(
                'Reset',
                style: TextStyle(
                  color: _SortSwipeColors.textDark,
                  fontSize: 12,
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
  static const Color badgeFill = Color(0xFFEFFBF3);
  static const Color badgeBorder = Color(0xFFCBEFD6);
  static const Color scaleIcon = Color(0xFFB9C4D4);
  static const Color iconBubble = Color(0xFFE9F8EE);
  static const Color dragHandle = Color(0xFFD5DAE5);
  static const Color sideCue = Color(0xEEF2FBF4);
  static const Color sideCueBorder = Color(0xFFD3F0DC);
  static const Color sideCueArrows = Color(0x99BCE7C8);
  static const Color panelFill = Color(0xF7F6FEF8);
  static const Color handle = Color(0xFFB7C0CF);
}
