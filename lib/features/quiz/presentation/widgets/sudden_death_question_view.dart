import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class SuddenDeathQuestionView extends StatefulWidget {
  final SuddenDeathQuestion question;
  final void Function(Answer answer) onSubmit;

  const SuddenDeathQuestionView({super.key, required this.question, required this.onSubmit});

  @override
  State<SuddenDeathQuestionView> createState() => _SuddenDeathQuestionViewState();
}

class _SuddenDeathQuestionViewState extends State<SuddenDeathQuestionView> {
  String? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: AppSpacing.paddingSm,
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.15),
            borderRadius: AppDimensions.radiusSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.whatshot, color: colors.error, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'SUDDEN DEATH — one wrong answer ends the quiz',
                style: context.appTextStyles.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(widget.question.prompt, style: context.appTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: RadioGroup<String>(
            groupValue: _selectedOptionId,
            onChanged: (value) => setState(() => _selectedOptionId = value),
            child: ListView.separated(
              itemCount: widget.question.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final option = widget.question.options[index];
                return RadioListTile<String>(
                  value: option.id,
                  title: Text(option.text),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Submit',
          onPressed: _selectedOptionId == null
              ? null
              : () => widget.onSubmit(
                    SuddenDeathAnswer(
                      questionId: widget.question.id,
                      selectedOptionId: _selectedOptionId!,
                    ),
                  ),
        ),
      ],
    );
  }
}
