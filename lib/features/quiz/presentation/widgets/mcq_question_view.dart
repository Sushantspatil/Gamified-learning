import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
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

class _McqQuestionViewState extends State<McqQuestionView>
    with SingleTickerProviderStateMixin {
  static const String _skippedOptionId = '__mcq_skipped__';

  late final AnimationController _questionMotionController;
  String? _selectedOptionId;
  final Set<String> _hiddenOptionIds = {};
  bool _isFiftyFiftyUsed = false;
  bool _isHintVisible = false;
  bool _isSubmitted = false;
  bool _isSkipUsed = false;
  McqCharacterState _characterState = McqCharacterState.idle;

  bool get _isFinalQuestion => widget.currentIndex >= widget.totalQuestions - 1;

  @override
  void initState() {
    super.initState();
    _questionMotionController = AnimationController(
      vsync: this,
      duration: AppMotion.page,
      reverseDuration: AppMotion.normal,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _questionMotionController.duration = AppMotion.duration(
      context,
      AppMotion.page,
    );
    _questionMotionController.reverseDuration = AppMotion.duration(
      context,
      AppMotion.normal,
    );
  }

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
      _questionMotionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _questionMotionController.dispose();
    super.dispose();
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
        _characterState = McqCharacterState.thinking;
      } else {
        _characterState = McqCharacterState.powerUp;
      }
    });
  }

  void _showHint() {
    if (_isSubmitted || _isHintVisible) return;
    setState(() {
      _isHintVisible = true;
      _characterState = McqCharacterState.thinking;
    });
  }

  Future<void> _skipQuestion() async {
    if (_isSubmitted || _isSkipUsed) return;

    setState(() {
      _isSkipUsed = true;
      _isSubmitted = true;
      _characterState = McqCharacterState.transition;
    });
    await _questionMotionController.reverse();
    if (!mounted) return;

    widget.onSubmit(
      McqAnswer(
        questionId: widget.question.id,
        selectedOptionId: _skippedOptionId,
      ),
    );
  }

  Future<void> _submitSelectedAnswer() async {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null || _isSubmitted) return;

    setState(() {
      _isSubmitted = true;
      _characterState = McqCharacterState.transition;
    });
    await _questionMotionController.reverse();
    if (!mounted) return;

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
    final buttonLabel = _isFinalQuestion ? 'Submit quiz' : 'Next';
    final visibleOptions = widget.question.options
        .where((option) => !_hiddenOptionIds.contains(option.id))
        .toList();
    final progress = widget.totalQuestions == 0
        ? 0.0
        : (widget.currentIndex + 1) / widget.totalQuestions;
    final selected = _selectedOptionId != null && !_isSubmitted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _McqHeader(
          currentIndex: widget.currentIndex,
          totalQuestions: widget.totalQuestions,
          progress: progress,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: FadeTransition(
            key: const Key('mcq_question_motion'),
            opacity: _questionMotionController.drive(
              CurveTween(curve: AppMotion.easeOut),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.045),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _questionMotionController,
                      curve: AppMotion.easeOut,
                      reverseCurve: AppMotion.easeIn,
                    ),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.question.prompt,
                    style: context.appTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  McqCharacterWidget(
                    key: ValueKey('mcq-character-${widget.question.id}'),
                    state: _characterState,
                    message: _isHintVisible ? hintText : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    key: const Key('mcq_options_section'),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: visibleOptions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final option = visibleOptions[index];
                        return _AnimatedMcqOption(
                          key: ValueKey(
                            'mcq-option-${widget.question.id}-${option.id}',
                          ),
                          controller: _questionMotionController,
                          index: index,
                          option: option,
                          isSelected: _selectedOptionId == option.id,
                          isDisabled: _isSubmitted,
                          onSelected: () {
                            if (_isSubmitted) return;
                            setState(() {
                              _selectedOptionId = option.id;
                              _characterState = McqCharacterState.acknowledge;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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
        AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          scale: selected ? 1 : 0.985,
          child: AnimatedOpacity(
            duration: AppMotion.duration(context, AppMotion.fast),
            opacity: selected ? 1 : 0.68,
            child: AppButton(
              label: buttonLabel,
              trailingIcon: Icon(
                _isFinalQuestion
                    ? Icons.emoji_events_rounded
                    : Icons.arrow_forward_rounded,
              ),
              onPressed: selected ? _submitSelectedAnswer : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _McqHeader extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final double progress;

  const _McqHeader({
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('MCQ Quiz', style: context.appTextStyles.titleLarge),
            ),
            AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.fast),
              child: Text(
                '${currentIndex + 1} / $totalQuestions',
                key: ValueKey(currentIndex),
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress),
          duration: AppMotion.duration(context, AppMotion.normal),
          curve: AppMotion.easeOut,
          builder: (context, value, child) {
            return AppProgressBar(
              value: value,
              height: 8,
              accentColor: colors.primary,
              trackColor: colors.primary.withValues(alpha: 0.10),
              semanticLabel: 'MCQ progress',
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedMcqOption extends StatelessWidget {
  final Animation<double> controller;
  final int index;
  final QuestionOption option;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onSelected;

  const _AnimatedMcqOption({
    super.key,
    required this.controller,
    required this.index,
    required this.option,
    required this.isSelected,
    required this.isDisabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = (0.18 + index * 0.10).clamp(0.0, 0.72);
    final end = (start + 0.36).clamp(start + 0.01, 1.0);
    final animation = controller.drive(
      CurveTween(curve: Interval(start, end, curve: AppMotion.easeOut)),
    );
    final horizontalOffset = index.isEven ? -0.045 : 0.045;

    return FadeTransition(
      key: Key('mcq_option_stagger_$index'),
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(horizontalOffset, 0.025),
          end: Offset.zero,
        ).animate(animation),
        child: AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          scale: isSelected ? 1.015 : 1,
          child: _McqOptionCard(
            option: option,
            isSelected: isSelected,
            isDisabled: isDisabled,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }
}

class _McqOptionCard extends StatelessWidget {
  final QuestionOption option;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onSelected;

  const _McqOptionCard({
    required this.option,
    required this.isSelected,
    required this.isDisabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final borderColor = isSelected ? colors.primary : colors.borderStrong;
    final accentColor = isSelected ? colors.primary : colors.secondary;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isDisabled,
      child: AppPressable(
        onTap: isDisabled ? null : onSelected,
        borderRadius: AppDimensions.radiusMd,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.normal),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accentColor.withValues(alpha: isSelected ? 0.14 : 0.055),
              colors.surface,
            ),
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(
              color: borderColor.withValues(alpha: isSelected ? 0.88 : 0.42),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.normal),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(
                    alpha: isSelected ? 0.20 : 0.10,
                  ),
                  border: Border.all(
                    color: accentColor.withValues(
                      alpha: isSelected ? 0.76 : 0.36,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.circle,
                  size: isSelected ? 10 : 7,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  option.text,
                  style: context.appTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
