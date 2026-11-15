import 'package:flutter/material.dart';

import '../../../../../app/theme/app_dimensions.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';

/// One line of the score breakdown: "Speed Bonus  +5".
class BreakdownLine {
  final String label;
  final String value;
  final Color color;

  const BreakdownLine({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// How the score was made up, ending in the final score. Shown inside the
/// "Score details" sheet, not on the result screen itself.
class ResultBreakdownCard extends StatelessWidget {
  final String title;
  final List<BreakdownLine> lines;
  final String finalLabel;
  final String finalValue;

  const ResultBreakdownCard({
    super.key,
    this.title = 'Score Breakdown',
    required this.lines,
    this.finalLabel = 'Final Score',
    required this.finalValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;

    TextStyle rowStyle(Color color, {bool bold = false}) => TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      fontSize: bold ? 15 : 13,
      color: color,
    );

    Widget row(String label, String value, Color color, {bool bold = false}) =>
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: rowStyle(color, bold: bold)),
            Text(value, style: rowStyle(color, bold: bold)),
          ],
        );

    return DecoratedBox(
      key: const Key('result_breakdown'),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: styles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final line in lines) ...[
              row(line.label, line.value, line.color),
              const SizedBox(height: 6),
            ],
            Divider(height: 18, color: colors.border.withValues(alpha: 0.3)),
            row(finalLabel, finalValue, colors.primary, bold: true),
          ],
        ),
      ),
    );
  }
}

/// The "Score details" sheet that slides up from the bottom of a result.
void showResultDetailsSheet(BuildContext context, List<Widget> children) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        key: const Key('result_details_sheet'),
        controller: controller,
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Score details',
              style: context.appTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    ),
  );
}
