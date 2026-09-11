import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';

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
  Set<String> _hiddenOptionIds = {};
  bool _isFiftyFiftyUsed = false;
  bool _isHintVisible = false;
  bool _isSkipUsed = false;
  bool _isSubmitted = false;

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
      _hiddenOptionIds = {};
      _isFiftyFiftyUsed = false;
      _isHintVisible = false;
      _isSkipUsed = false;
      _isSubmitted = false;
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
      _hiddenOptionIds = {
        ..._hiddenOptionIds,
        ...incorrectOptions.take(removeCount).map((option) => option.id),
      };
      if (_selectedOptionId != null &&
          _hiddenOptionIds.contains(_selectedOptionId)) {
        _selectedOptionId = null;
      }
    });
  }

  void _showHint() {
    if (_isSubmitted || _isHintVisible) return;
    setState(() => _isHintVisible = true);
  }

  void _skipQuestion() {
    if (_isSubmitted || _isSkipUsed) return;
    setState(() => _isSkipUsed = true);
    _submitAnswer(_skippedOptionId);
  }

  Future<void> _submitSelectedAnswer() async {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null) return;
    await _submitAnswer(selectedOptionId);
  }

  Future<void> _submitAnswer(String selectedOptionId) async {
    if (_isSubmitted) return;

    setState(() => _isSubmitted = true);
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
    final progress = widget.totalQuestions == 0
        ? 0.0
        : (widget.currentIndex + 1) / widget.totalQuestions;
    final buttonLabel = _isFinalQuestion ? 'Submit quiz' : 'Next';

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
          child: SingleChildScrollView(
            child: FadeTransition(
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
                      style: context.appTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GamePowerUpBar(
                      coinBalanceOverride: widget.coins,
                      isDisabled: _isSubmitted,
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
                          description:
                              'Show a helpful clue without revealing the answer.',
                          coinCost: 10,
                          icon: Icons.lightbulb_outline,
                          isUsed: _isHintVisible,
                          onUse: _showHint,
                        ),
                        GamePowerUpAction(
                          id: 'mcq-skip',
                          label: 'Skip',
                          description: 'Move on without selecting an answer.',
                          coinCost: 25,
                          icon: Icons.fast_forward_rounded,
                          isUsed: _isSkipUsed,
                          onUse: _skipQuestion,
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: AppMotion.duration(context, AppMotion.normal),
                      alignment: Alignment.topCenter,
                      child: _isHintVisible
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: _HintPanel(
                                text:
                                    widget.question.hint ??
                                    'Read the question carefully and eliminate choices that do not fit.',
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final indexed in widget.question.options.indexed) ...[
                      _AnimatedMcqOption(
                        key: ValueKey(
                          'mcq-option-${widget.question.id}-${indexed.$2.id}',
                        ),
                        controller: _questionMotionController,
                        index: indexed.$1,
                        option: indexed.$2,
                        isSelected: _selectedOptionId == indexed.$2.id,
                        isHidden: _hiddenOptionIds.contains(indexed.$2.id),
                        isDisabled: _isSubmitted,
                        onSelected: () {
                          if (_isSubmitted ||
                              _hiddenOptionIds.contains(indexed.$2.id)) {
                            return;
                          }
                          setState(() => _selectedOptionId = indexed.$2.id);
                        },
                      ),
                      if (indexed.$1 != widget.question.options.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          scale: _selectedOptionId == null || _isSubmitted ? 0.98 : 1,
          child: AnimatedOpacity(
            duration: AppMotion.duration(context, AppMotion.fast),
            opacity: _selectedOptionId == null || _isSubmitted ? 0.62 : 1,
            child: AppButton(
              label: buttonLabel,
              trailingIcon: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.fast),
                child: Icon(
                  _isFinalQuestion
                      ? Icons.emoji_events_rounded
                      : Icons.arrow_forward_rounded,
                  key: ValueKey(buttonLabel),
                ),
              ),
              onPressed: _selectedOptionId == null || _isSubmitted
                  ? null
                  : _submitSelectedAnswer,
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

class _HintPanel extends StatelessWidget {
  final String text;

  const _HintPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: AppSpacing.paddingSm,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colors.primary, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: context.appTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMcqOption extends StatelessWidget {
  final Animation<double> controller;
  final int index;
  final QuestionOption option;
  final bool isSelected;
  final bool isHidden;
  final bool isDisabled;
  final VoidCallback onSelected;

  const _AnimatedMcqOption({
    super.key,
    required this.controller,
    required this.index,
    required this.option,
    required this.isSelected,
    required this.isHidden,
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
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(horizontalOffset, 0.02),
          end: Offset.zero,
        ).animate(animation),
        child: AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.normal),
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: AppMotion.duration(context, AppMotion.normal),
            opacity: isHidden ? 0 : 1,
            child: AnimatedScale(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.easeOut,
              scale: isHidden
                  ? 0.96
                  : isSelected
                  ? 1.02
                  : 1,
              child: isHidden
                  ? const SizedBox.shrink()
                  : _McqOptionCard(
                      option: option,
                      isSelected: isSelected,
                      isDisabled: isDisabled,
                      onSelected: onSelected,
                    ),
            ),
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

    return AppPressable(
      onTap: isDisabled ? null : onSelected,
      borderRadius: AppDimensions.radiusMd,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(
            color: isSelected ? colors.primary : colors.borderStrong,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            ...AppElevation.shadows(colors, 1),
            if (isSelected)
              BoxShadow(
                color: colors.secondary.withValues(alpha: 0.18),
                blurRadius: 16,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.fast),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.secondary.withValues(alpha: 0.16)
                      : colors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.secondary : colors.borderStrong,
                    width: isSelected ? 2.2 : 1.4,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    width: isSelected ? 9 : 0,
                    height: isSelected ? 9 : 0,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  option.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
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
