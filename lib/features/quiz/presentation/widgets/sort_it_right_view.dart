import 'package:flutter/material.dart';

import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

enum SortBucket { unsorted, debit, credit }

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
  late List<String> _unsortedEntries;
  final List<String> _debitEntries = [];
  final List<String> _creditEntries = [];
  String? _selectedEntry;

  static const Set<String> _correctDebitEntries = {
    'Purchase',
    'Salary Paid',
    'Discount Allowed',
  };
  static const Set<String> _correctCreditEntries = {'Cash Received'};

  @override
  void initState() {
    super.initState();
    _unsortedEntries = List.of(widget.question.itemsInOrder);
  }

  void _reset() {
    setState(() {
      _unsortedEntries = List.of(widget.question.itemsInOrder);
      _debitEntries.clear();
      _creditEntries.clear();
      _selectedEntry = null;
    });
  }

  void _moveEntry(String entry, SortBucket target) {
    setState(() {
      _unsortedEntries.remove(entry);
      _debitEntries.remove(entry);
      _creditEntries.remove(entry);

      switch (target) {
        case SortBucket.unsorted:
          _unsortedEntries.add(entry);
        case SortBucket.debit:
          _debitEntries.add(entry);
        case SortBucket.credit:
          _creditEntries.add(entry);
      }
      _selectedEntry = null;
    });
  }

  void _handleDropZoneTap(SortBucket target) {
    final entry = _selectedEntry;
    if (entry == null) return;
    _moveEntry(entry, target);
  }

  void _submit() {
    final isComplete = _unsortedEntries.isEmpty;
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
    return ColoredBox(
      color: _SortQuizColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            SortQuizTopBar(
              coins: widget.coins,
              energy: widget.energy,
              onBack: widget.onExit,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SortQuizProgressCard(
                      currentQuestion: widget.currentIndex + 1,
                      totalQuestions: widget.totalQuestions,
                      streak: widget.currentStreak,
                    ),
                    const SizedBox(height: 16),
                    SortQuestionCard(
                      question: widget.question,
                      unsortedEntries: _unsortedEntries,
                      debitEntries: _debitEntries,
                      creditEntries: _creditEntries,
                      selectedEntry: _selectedEntry,
                      onEntrySelected: (entry) {
                        setState(() {
                          _selectedEntry = _selectedEntry == entry
                              ? null
                              : entry;
                        });
                      },
                      onEntryDropped: _moveEntry,
                      onDropZoneTap: _handleDropZoneTap,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            _SortBottomActionArea(onReset: _reset, onSubmit: _submit),
          ],
        ),
      ),
    );
  }
}

class SortQuizTopBar extends StatelessWidget {
  final int coins;
  final int energy;
  final VoidCallback onBack;

  const SortQuizTopBar({
    super.key,
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
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sort It Out',
                  style: TextStyle(
                    color: _SortQuizColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '✦ Arrange in correct order ✦',
                  style: TextStyle(
                    color: _SortQuizColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SortStatChip(
                icon: Icons.monetization_on_rounded,
                value: coins.toString(),
                iconColor: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              SortStatChip(
                icon: Icons.bolt_rounded,
                value: energy.toString(),
                iconColor: Color(0xFFFFB020),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SortStatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color iconColor;

  const SortStatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: _SortQuizDecoration.softCard(radius: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: _SortQuizColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SortQuizProgressCard extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int streak;

  const SortQuizProgressCard({
    super.key,
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _SortQuizDecoration.softCard(radius: 20),
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
                        color: _SortQuizColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$currentQuestion / $totalQuestions',
                      style: const TextStyle(
                        color: _SortQuizColors.textDark,
                        fontSize: 24,
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
                      color: _SortQuizColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.deepOrangeAccent.shade200,
                        size: 20,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        streak.toString(),
                        style: const TextStyle(
                          color: _SortQuizColors.green,
                          fontSize: 20,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: _SortQuizColors.green,
                    backgroundColor: _SortQuizColors.greenTrack,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _SortQuizColors.green,
                  fontSize: 12,
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

class SortQuestionCard extends StatelessWidget {
  final SortItRightQuestion question;
  final List<String> unsortedEntries;
  final List<String> debitEntries;
  final List<String> creditEntries;
  final String? selectedEntry;
  final ValueChanged<String> onEntrySelected;
  final void Function(String entry, SortBucket target) onEntryDropped;
  final ValueChanged<SortBucket> onDropZoneTap;

  const SortQuestionCard({
    super.key,
    required this.question,
    required this.unsortedEntries,
    required this.debitEntries,
    required this.creditEntries,
    required this.selectedEntry,
    required this.onEntrySelected,
    required this.onEntryDropped,
    required this.onDropZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _SortQuizDecoration.softCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ModeBadge(icon: Icons.home_rounded, label: 'Challenge'),
              const Spacer(),
              ModeBadge(label: '+${question.points} XP'),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    color: _SortQuizColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.42,
                  ),
                ),
              ),
              const Positioned(
                right: 7,
                top: 2,
                child: Icon(
                  Icons.balance_rounded,
                  color: _SortQuizColors.scaleIcon,
                  size: 66,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SortDropZone(
                  title: 'Debit',
                  entries: debitEntries,
                  selectedEntry: selectedEntry,
                  target: SortBucket.debit,
                  placeholder: 'Drop debit entries\nhere',
                  onEntrySelected: onEntrySelected,
                  onEntryDropped: onEntryDropped,
                  onTap: () => onDropZoneTap(SortBucket.debit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SortDropZone(
                  title: 'Credit',
                  entries: creditEntries,
                  selectedEntry: selectedEntry,
                  target: SortBucket.credit,
                  placeholder: 'Drop credit entries\nhere',
                  onEntrySelected: onEntrySelected,
                  onEntryDropped: onEntryDropped,
                  onTap: () => onDropZoneTap(SortBucket.credit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _UnsortedEntriesPanel(
            entries: unsortedEntries,
            selectedEntry: selectedEntry,
            onEntrySelected: onEntrySelected,
            onEntryDropped: onEntryDropped,
          ),
        ],
      ),
    );
  }
}

class SortDropZone extends StatelessWidget {
  final String title;
  final String placeholder;
  final List<String> entries;
  final String? selectedEntry;
  final SortBucket target;
  final ValueChanged<String> onEntrySelected;
  final void Function(String entry, SortBucket target) onEntryDropped;
  final VoidCallback onTap;

  const SortDropZone({
    super.key,
    required this.title,
    required this.placeholder,
    required this.entries,
    required this.selectedEntry,
    required this.target,
    required this.onEntrySelected,
    required this.onEntryDropped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onEntryDropped(details.data, target),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? _SortQuizColors.lightGreen
                  : _SortQuizColors.dropBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _SortQuizColors.dropBorder, width: 1.3),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _SortQuizColors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                CustomPaint(
                  painter: _DashedBorderPainter(
                    color: _SortQuizColors.dropBorder,
                    radius: 12,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsets.all(8),
                    child: entries.isEmpty
                        ? _DropPlaceholder(text: placeholder)
                        : Column(
                            children: [
                              for (final entry in entries) ...[
                                SortableEntryTile(
                                  entry: entry,
                                  compact: true,
                                  isSelected: selectedEntry == entry,
                                  onTap: () => onEntrySelected(entry),
                                ),
                                if (entry != entries.last)
                                  const SizedBox(height: 7),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SortableEntryTile extends StatelessWidget {
  final String entry;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const SortableEntryTile({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(minHeight: compact ? 34 : 42),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _SortQuizColors.lightGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _SortQuizColors.green
                  : _SortQuizColors.border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                color: _SortQuizColors.handle,
                size: compact ? 16 : 19,
              ),
              SizedBox(width: compact ? 5 : 10),
              Expanded(
                child: Text(
                  entry,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _SortQuizColors.textDark,
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!compact)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _SortQuizColors.muted,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );

    return LongPressDraggable<String>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: tile),
      child: tile,
    );
  }
}

class ModeBadge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const ModeBadge({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _SortQuizColors.lightGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _SortQuizColors.green, size: 15),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _SortQuizColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_SortQuizColors.green, _SortQuizColors.greenDark],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3322C55E),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsortedEntriesPanel extends StatelessWidget {
  final List<String> entries;
  final String? selectedEntry;
  final ValueChanged<String> onEntrySelected;
  final void Function(String entry, SortBucket target) onEntryDropped;

  const _UnsortedEntriesPanel({
    required this.entries,
    required this.selectedEntry,
    required this.onEntrySelected,
    required this.onEntryDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          onEntryDropped(details.data, SortBucket.unsorted),
      builder: (context, candidateData, rejectedData) {
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _SortQuizColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Unsorted Entries',
                style: TextStyle(
                  color: _SortQuizColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 9),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'All entries sorted',
                    style: TextStyle(
                      color: _SortQuizColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                for (final entry in entries) ...[
                  SortableEntryTile(
                    entry: entry,
                    isSelected: selectedEntry == entry,
                    onTap: () => onEntrySelected(entry),
                  ),
                  if (entry != entries.last) const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _SortBottomActionArea extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onSubmit;

  const _SortBottomActionArea({required this.onReset, required this.onSubmit});

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
              Expanded(
                child: GradientActionButton(
                  label: 'Submit Sort',
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Place each entry in the correct column',
            style: TextStyle(
              color: _SortQuizColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 44,
          height: 44,
          decoration: _SortQuizDecoration.softCard(radius: 14),
          child: const Icon(
            Icons.sync_rounded,
            color: _SortQuizColors.green,
            size: 24,
          ),
        ),
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
          width: 38,
          height: 38,
          decoration: _SortQuizDecoration.softCard(radius: 19),
          child: Icon(icon, color: _SortQuizColors.textDark, size: 21),
        ),
      ),
    );
  }
}

class _DropPlaceholder extends StatelessWidget {
  final String text;

  const _DropPlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.arrow_downward_rounded,
            color: _SortQuizColors.dropBorder,
            size: 27,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _SortQuizColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
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
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 5.0;
      const dashSpace = 4.0;
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

class _SortQuizDecoration {
  _SortQuizDecoration._();

  static BoxDecoration softCard({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _SortQuizColors.border),
      boxShadow: const [
        BoxShadow(
          color: _SortQuizColors.shadow,
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

class _SortQuizColors {
  _SortQuizColors._();

  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE5E7EB);
  static const Color lightGreen = Color(0xFFECFDF5);
  static const Color dropBackground = Color(0xFFF7FEFA);
  static const Color dropBorder = Color(0xFF86EFAC);
  static const Color greenTrack = Color(0xFFDDF7E8);
  static const Color scaleIcon = Color(0xFFD7E2F1);
  static const Color handle = Color(0xFFCBD5E1);
  static const Color shadow = Color(0x120F172A);
}
