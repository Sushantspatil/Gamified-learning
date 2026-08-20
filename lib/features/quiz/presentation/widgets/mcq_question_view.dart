import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class McqQuestionView extends StatefulWidget {
  final McqQuestion question;
  final void Function(Answer answer) onSubmit;

  const McqQuestionView({super.key, required this.question, required this.onSubmit});

  @override
  State<McqQuestionView> createState() => _McqQuestionViewState();
}

class _McqQuestionViewState extends State<McqQuestionView> {
  String? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    McqAnswer(questionId: widget.question.id, selectedOptionId: _selectedOptionId!),
                  ),
        ),
      ],
    );
  }
}
