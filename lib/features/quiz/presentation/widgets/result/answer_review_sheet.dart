import 'package:flutter/material.dart';

import '../../../../../app/theme/app_dimensions.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../domain/result_answers.dart';

/// Slides up from the bottom to show every question with the player's answer in
/// red when it was wrong and the right answer in green. It opens on the wrong
/// ones (the ones worth learning from) and can show all.
Future<void> showAnswerReview(BuildContext context, List<ReviewItem> items) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          AnswerReview(items: items, controller: controller),
    ),
  );
}

class AnswerReview extends StatefulWidget {
  final List<ReviewItem> items;
  final ScrollController controller;

  const AnswerReview({
    super.key,
    required this.items,
    required this.controller,
  });

  @override
  State<AnswerReview> createState() => _AnswerReviewState();
}

class _AnswerReviewState extends State<AnswerReview> {
  late bool _onlyWrong = widget.items.any((i) => !i.isCorrect);

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final wrong = widget.items.where((i) => !i.isCorrect).length;
    final shown = _onlyWrong
        ? widget.items.where((i) => !i.isCorrect).toList()
        : widget.items;

    return ListView(
      key: const Key('answer_review'),
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'Your answers',
          style: styles.titleLarge.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          wrong == 0
              ? 'Every answer was right. Perfect!'
              : '$wrong wrong, ${widget.items.length - wrong} right',
          style: styles.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        if (wrong > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                key: const Key('review_filter_wrong'),
                label: Text('Wrong ($wrong)'),
                selected: _onlyWrong,
                onSelected: (_) => setState(() => _onlyWrong = true),
              ),
              ChoiceChip(
                key: const Key('review_filter_all'),
                label: Text('All (${widget.items.length})'),
                selected: !_onlyWrong,
                onSelected: (_) => setState(() => _onlyWrong = false),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final item in shown) _ReviewCard(item: item),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewItem item;

  const _ReviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final badge = item.isCorrect ? colors.success : colors.error;

    return Padding(
      key: Key('review_item_${item.number}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: badge.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badge,
                    ),
                    child: Text(
                      '${item.number}',
                      style: styles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.prompt,
                      style: styles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!item.isCorrect)
                _AnswerLine(
                  key: const Key('review_your_answer'),
                  right: false,
                  label: 'Your answer',
                  text: item.yourAnswer ?? 'No answer',
                ),
              _AnswerLine(
                key: const Key('review_correct_answer'),
                right: true,
                label: item.isCorrect ? 'Your answer' : 'Correct answer',
                text: item.correctAnswer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final bool right;
  final String label;
  final String text;

  const _AnswerLine({
    super.key,
    required this.right,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final color = right ? colors.success : colors.error;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            right ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: styles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  text,
                  style: styles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
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
