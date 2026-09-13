import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';
import 'mcq_character_widget.dart';

class McqQuestionView extends StatefulWidget {
  final McqQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int coins;
  final int energy;
  final VoidCallback onExit;
  final void Function(Answer answer) onSubmit;

  const McqQuestionView({
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
  State<McqQuestionView> createState() => _McqQuestionViewState();
}

class _McqQuestionViewState extends State<McqQuestionView> {
  static const String _skippedOptionId = '__mcq_skipped__';

  String? _selectedOptionId;
  final Set<String> _hiddenOptionIds = {};
  bool _isFiftyFiftyUsed = false;
  bool _isHintVisible = false;
  bool _isSubmitted = false;
  bool _isSkipUsed = false;
  McqCharacterState _characterState = McqCharacterState.idle;

  @override
  void didUpdateWidget(covariant McqQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _selectedOptionId = null;
      _hiddenOptionIds.clear();
      _isFiftyFiftyUsed = false;
      _isHintVisible = false;
      _isSubmitted = false;
      _isSkipUsed = false;
      _characterState = McqCharacterState.idle;
    }
  }

  void _useFiftyFifty() {
    if (_isSubmitted || _isFiftyFiftyUsed) return;

    final incorrectOptions =
        widget.question.options
            .where((option) => option.id != widget.question.correctOptionId)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final removeCount = incorrectOptions.length < 2
        ? incorrectOptions.length
        : 2;

    setState(() {
      _isFiftyFiftyUsed = true;
      _hiddenOptionIds.addAll(
        incorrectOptions.take(removeCount).map((option) => option.id),
      );
      if (_selectedOptionId != null &&
          _hiddenOptionIds.contains(_selectedOptionId)) {
        _selectedOptionId = null;
      }
      _characterState = McqCharacterState.powerUp;
    });
  }

  void _showHint() {
    if (_isSubmitted) return;
    setState(() {
      _isHintVisible = true;
      _characterState = McqCharacterState.thinking;
    });
  }

  void _skipQuestion() {
    if (_isSubmitted || _isSkipUsed) return;

    setState(() {
      _isSkipUsed = true;
      _isSubmitted = true;
      _characterState = McqCharacterState.transition;
    });
    widget.onSubmit(
      McqAnswer(
        questionId: widget.question.id,
        selectedOptionId: _skippedOptionId,
      ),
    );
  }

  void _submitSelectedAnswer() {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null || _isSubmitted) return;

    setState(() => _isSubmitted = true);
    widget.onSubmit(
      McqAnswer(
        questionId: widget.question.id,
        selectedOptionId: selectedOptionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintText =
        widget.question.hint ??
        'Read the question carefully and eliminate choices that do not fit.';
    final buttonLabel = widget.currentIndex >= widget.totalQuestions - 1
        ? 'Submit quiz'
        : 'Next';
    final visibleOptions = widget.question.options
        .where((option) => !_hiddenOptionIds.contains(option.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('MCQ Quiz', style: context.appTextStyles.titleLarge),
            ),
            Text(
              '${widget.currentIndex + 1} / ${widget.totalQuestions}',
              style: context.appTextStyles.labelLarge.copyWith(
                color: context.themeColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(widget.question.prompt, style: context.appTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.md),
        McqCharacterWidget(
          state: _characterState,
          message: _isHintVisible ? hintText : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          key: const Key('mcq_options_section'),
          child: RadioGroup<String>(
            groupValue: _selectedOptionId,
            onChanged: (value) {
              if (_isSubmitted ||
                  value == null ||
                  _hiddenOptionIds.contains(value)) {
                return;
              }
              setState(() {
                _selectedOptionId = value;
                _characterState = McqCharacterState.acknowledge;
              });
            },
            child: ListView.separated(
              itemCount: visibleOptions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final option = visibleOptions[index];
                return RadioListTile<String>(
                  value: option.id,
                  enabled: !_isSubmitted,
                  title: Text(option.text),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GamePowerUpBar(
          coinBalanceOverride: widget.coins,
          isDisabled: _isSubmitted,
          showWallet: false,
          actions: [
            GamePowerUpAction(
              id: '50-50',
              label: '50:50',
              description: 'Remove two wrong answers.',
              coinCost: 20,
              icon: Icons.filter_2,
              isUsed: _isFiftyFiftyUsed,
              onUse: _useFiftyFifty,
            ),
            GamePowerUpAction(
              id: 'hint',
              label: 'Hint',
              description: 'Show a helpful clue without revealing the answer.',
              coinCost: 10,
              icon: Icons.lightbulb_outline,
              isUsed: _isHintVisible,
              onUse: _showHint,
            ),
            GamePowerUpAction(
              id: 'skip',
              label: 'Skip',
              description: 'Skip this question safely.',
              coinCost: 30,
              icon: Icons.fast_forward_rounded,
              isUsed: _isSkipUsed,
              onUse: _skipQuestion,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: buttonLabel,
          onPressed: _selectedOptionId == null || _isSubmitted
              ? null
              : _submitSelectedAnswer,
        ),
      ],
    );
  }
}
