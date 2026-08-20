import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class MatchTheFollowingView extends StatefulWidget {
  final MatchTheFollowingQuestion question;
  final void Function(Answer answer) onSubmit;

  const MatchTheFollowingView({super.key, required this.question, required this.onSubmit});

  @override
  State<MatchTheFollowingView> createState() => _MatchTheFollowingViewState();
}

class _MatchTheFollowingViewState extends State<MatchTheFollowingView> {
  late final List<MatchPair> _shuffledRight;
  final Map<String, String> _matches = {}; // leftPairId -> rightPairId
  String? _selectedLeftPairId;

  @override
  void initState() {
    super.initState();
    _shuffledRight = List.of(widget.question.pairs);
    // Deterministic-enough shuffle for a mock question bank; not
    // security-sensitive, just needs to not start in the "already correct"
    // order.
    _shuffledRight.shuffle(Random(widget.question.id.hashCode));
  }

  void _handleLeftTap(String pairId) {
    if (_matches.containsKey(pairId)) {
      setState(() => _matches.remove(pairId));
      return;
    }
    setState(() => _selectedLeftPairId = pairId);
  }

  void _handleRightTap(String pairId) {
    final selectedLeft = _selectedLeftPairId;
    if (selectedLeft == null) return;
    setState(() {
      _matches[selectedLeft] = pairId;
      _selectedLeftPairId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allMatched = _matches.length == widget.question.pairs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.question.prompt, style: context.appTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (final pair in widget.question.pairs)
                      _MatchChip(
                        label: pair.left,
                        isMatched: _matches.containsKey(pair.id),
                        isSelected: _selectedLeftPairId == pair.id,
                        onTap: () => _handleLeftTap(pair.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    for (final pair in _shuffledRight)
                      _MatchChip(
                        label: pair.right,
                        isMatched: _matches.containsValue(pair.id),
                        isSelected: false,
                        onTap: () => _handleRightTap(pair.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Submit',
          onPressed: allMatched
              ? () => widget.onSubmit(
                    MatchTheFollowingAnswer(
                      questionId: widget.question.id,
                      matchedPairIds: Map.of(_matches),
                    ),
                  )
              : null,
        ),
      ],
    );
  }
}

class _MatchChip extends StatelessWidget {
  final String label;
  final bool isMatched;
  final bool isSelected;
  final VoidCallback onTap;

  const _MatchChip({
    required this.label,
    required this.isMatched,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final Color borderColor = isMatched
        ? colors.success
        : isSelected
            ? colors.primary
            : colors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPressable(
        onTap: onTap,
        borderRadius: AppDimensions.radiusSm,
        child: Container(
          width: double.infinity,
          padding: AppSpacing.paddingSm,
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: AppDimensions.radiusSm,
            border: Border.all(color: borderColor, width: isSelected || isMatched ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: context.appTextStyles.bodyMedium)),
              if (isMatched) Icon(Icons.check, color: colors.success, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
