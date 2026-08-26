import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class SuddenDeathQuestionView extends StatefulWidget {
  final SuddenDeathQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final VoidCallback onExit;
  final void Function(Answer answer) onSubmit;

  const SuddenDeathQuestionView({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.onExit,
    required this.onSubmit,
  });

  @override
  State<SuddenDeathQuestionView> createState() =>
      _SuddenDeathQuestionViewState();
}

class _SuddenDeathQuestionViewState extends State<SuddenDeathQuestionView> {
  String? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.background,
            Color.alphaBlend(
              colors.primary.withValues(alpha: 0.14),
              colors.backgroundSecondary,
            ),
            colors.background,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SuddenDeathArenaPainter(colors)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 680;

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          isCompact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SuddenDeathTopBar(onExit: widget.onExit),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            _SuddenDeathStatusRow(
                              currentIndex: widget.currentIndex,
                              totalQuestions: widget.totalQuestions,
                              currentStreak: widget.currentStreak,
                              points: widget.question.points,
                            ),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            _QuestionPanel(
                              question: widget.question,
                              selectedOptionId: _selectedOptionId,
                              onSelected: (optionId) =>
                                  setState(() => _selectedOptionId = optionId),
                            ),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            _DangerBanner(points: widget.question.points),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        isCompact ? AppSpacing.sm : AppSpacing.md,
                      ),
                      child: AppButton(
                        label: 'Submit',
                        variant: AppButtonVariant.destructive,
                        leadingIcon: const Icon(Icons.bolt_rounded),
                        onPressed: _selectedOptionId == null
                            ? null
                            : () => widget.onSubmit(
                                SuddenDeathAnswer(
                                  questionId: widget.question.id,
                                  selectedOptionId: _selectedOptionId!,
                                ),
                              ),
                      ),
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

class _SuddenDeathTopBar extends StatelessWidget {
  final VoidCallback onExit;

  const _SuddenDeathTopBar({required this.onExit});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Row(
      children: [
        Tooltip(
          message: 'Back',
          child: InkWell(
            onTap: onExit,
            borderRadius: AppDimensions.radiusMd,
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.16),
                borderRadius: AppDimensions.radiusMd,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.38),
                ),
              ),
              child: Icon(Icons.arrow_back_rounded, color: colors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.streakFire,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Sudden Death',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.titleLarge.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'One wrong answer ends the run.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuddenDeathStatusRow extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int points;

  const _SuddenDeathStatusRow({
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.82),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HudMetric(
              label: 'Question',
              value: '${currentIndex + 1} / $totalQuestions',
              icon: Icons.quiz_rounded,
              color: colors.secondary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: _RiskMedallion(points: points),
          ),
          Expanded(
            child: _HudMetric(
              label: 'Current streak',
              value: '$currentStreak',
              icon: Icons.whatshot_rounded,
              color: AppColors.streakFire,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alignEnd;

  const _HudMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTextStyles.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.display.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(icon, color: color, size: 22),
          ],
        ),
      ],
    );
  }
}

class _RiskMedallion extends StatelessWidget {
  final int points;

  const _RiskMedallion({required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return SizedBox(
      width: 92,
      height: 92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.streakFire, width: 3),
          color: Color.alphaBlend(
            colors.error.withValues(alpha: 0.12),
            colors.surface,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$points',
                style: context.appTextStyles.headingLarge.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'PTS',
                style: context.appTextStyles.labelSmall.copyWith(
                  color: colors.textPrimary,
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

class _QuestionPanel extends StatelessWidget {
  final SuddenDeathQuestion question;
  final String? selectedOptionId;
  final ValueChanged<String> onSelected;

  const _QuestionPanel({
    required this.question,
    required this.selectedOptionId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.92),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.14),
                  borderRadius: AppDimensions.radiusSm,
                  border: Border.all(
                    color: colors.secondary.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'No mistakes',
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _PointsChip(points: question.points),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            question.prompt,
            style: context.appTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < question.options.length; i++) ...[
            _AnswerCard(
              label: String.fromCharCode(65 + i),
              option: question.options[i],
              isSelected: selectedOptionId == question.options[i].id,
              onTap: () => onSelected(question.options[i].id),
            ),
            if (i != question.options.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  final int points;

  const _PointsChip({required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.14),
        borderRadius: AppDimensions.radiusSm,
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.coinGold, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$points points',
            style: context.appTextStyles.labelLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String label;
  final QuestionOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.label,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final accent = isSelected ? colors.success : colors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.radiusMd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: isSelected ? 0.16 : 0.07),
              colors.surface,
            ),
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(
              color: accent.withValues(alpha: isSelected ? 0.88 : 0.28),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: isSelected ? 0.2 : 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.72)),
                ),
                child: Text(
                  label,
                  style: context.appTextStyles.titleMedium.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  option.text,
                  style: context.appTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: colors.success,
                        size: 28,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('idle'),
                        color: colors.textMuted,
                        size: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerBanner extends StatelessWidget {
  final int points;

  const _DangerBanner({required this.points});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.error.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_rounded, color: colors.error),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Lock in carefully. A correct answer keeps your streak alive and earns $points points.',
              style: context.appTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuddenDeathArenaPainter extends CustomPainter {
  final AppThemeColors colors;

  const _SuddenDeathArenaPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final primaryPaint = Paint()
      ..color = colors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1.1;
    final firePaint = Paint()
      ..color = AppColors.streakFire.withValues(alpha: 0.12)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.15 + i * 0.18);
      final y = size.height * (0.16 + (i.isEven ? 0.16 : 0.34));
      canvas.drawLine(Offset(x, y), Offset(x + 18, y - 10), firePaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.12,
          size.width * 0.88,
          size.height * 0.74,
        ),
        const Radius.circular(AppDimensions.borderRadiusCard),
      ),
      primaryPaint,
    );
  }

  @override
  bool shouldRepaint(_SuddenDeathArenaPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
