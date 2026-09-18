import 'package:flutter/material.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
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
    final submitButton = AnimatedScale(
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _McqHeader(
          currentIndex: widget.currentIndex,
          totalQuestions: widget.totalQuestions,
          progress: progress,
          coins: widget.coins,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final companionHeight = _companionHeightFor(
                constraints.maxHeight,
              );

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          QuizCompanionPlaceholder(height: companionHeight),
                          const SizedBox(height: AppSpacing.md),
                          for (final indexed
                              in widget.question.options.indexed) ...[
                            _AnimatedMcqOption(
                              key: ValueKey(
                                'mcq-option-${widget.question.id}-${indexed.$2.id}',
                              ),
                              controller: _questionMotionController,
                              index: indexed.$1,
                              option: indexed.$2,
                              isSelected: _selectedOptionId == indexed.$2.id,
                              isHidden: _hiddenOptionIds.contains(
                                indexed.$2.id,
                              ),
                              isDisabled: _isSubmitted,
                              onSelected: () {
                                if (_isSubmitted ||
                                    _hiddenOptionIds.contains(indexed.$2.id)) {
                                  return;
                                }
                                setState(
                                  () => _selectedOptionId = indexed.$2.id,
                                );
                              },
                            ),
                            if (indexed.$1 !=
                                widget.question.options.length - 1)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                          AnimatedSize(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.normal,
                            ),
                            alignment: Alignment.topCenter,
                            child: _isHintVisible
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: _HintPanel(
                                      text:
                                          widget.question.hint ??
                                          'Read the question carefully and eliminate choices that do not fit.',
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
                                description:
                                    'Move on without selecting an answer.',
                                coinCost: 25,
                                icon: Icons.fast_forward_rounded,
                                isUsed: _isSkipUsed,
                                onUse: _skipQuestion,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          submitButton,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _companionHeightFor(double availableHeight) {
    final reservedControlHeight = _isHintVisible ? 568.0 : 512.0;
    final targetHeight = availableHeight - reservedControlHeight;
    return targetHeight.clamp(112.0, 240.0);
  }
}

class QuizCompanionPlaceholder extends StatefulWidget {
  final double? height;

  const QuizCompanionPlaceholder({super.key, this.height});

  @override
  State<QuizCompanionPlaceholder> createState() =>
      _QuizCompanionPlaceholderState();
}

class _QuizCompanionPlaceholderState extends State<QuizCompanionPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loopController;

  bool get _isWidgetTestBinding {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      value: 0.45,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate =
        !AppMotion.reduceMotion(context) && !_isWidgetTestBinding;

    if (shouldAnimate && !_loopController.isAnimating) {
      _loopController.repeat(reverse: true);
    } else if (!shouldAnimate && _loopController.isAnimating) {
      _loopController.stop();
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height =
        widget.height ?? _placeholderHeight(MediaQuery.sizeOf(context).height);

    return Semantics(
      container: true,
      label: 'Your Quiz Companion coming soon',
      child: SizedBox(
        key: const Key('quiz_companion_placeholder'),
        height: height,
        child: AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            final pulse = Curves.easeInOut.transform(_loopController.value);
            final translateY = -4 * pulse;
            final glowOpacity = 0.4 + (0.4 * pulse);
            final textOpacity = 0.82 + (0.14 * pulse);

            return Transform.translate(
              offset: Offset(0, translateY),
              child: _QuizCompanionPlaceholderContent(
                glowOpacity: glowOpacity,
                textOpacity: textOpacity,
              ),
            );
          },
        ),
      ),
    );
  }

  double _placeholderHeight(double screenHeight) {
    if (screenHeight < 680) return 110;
    if (screenHeight < 780) return 124;
    return 140;
  }
}

class _QuizCompanionPlaceholderContent extends StatelessWidget {
  final double glowOpacity;
  final double textOpacity;

  const _QuizCompanionPlaceholderContent({
    required this.glowOpacity,
    required this.textOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppDimensions.radiusMd,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryDark.withValues(alpha: 0.24),
            colors.surfaceElevated.withValues(alpha: 0.70),
            colors.secondary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: colors.violet.withValues(alpha: 0.14 * glowOpacity),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppDimensions.radiusMd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 104;
            final avatarSize = isCompact ? 34.0 : 50.0;
            final verticalPadding = isCompact ? 4.0 : AppSpacing.sm;
            final avatarGap = isCompact ? 0.0 : AppSpacing.xs;

            return CustomPaint(
              painter: _QuizCompanionGlowPainter(
                colors: colors,
                glowOpacity: glowOpacity,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: CustomPaint(
                          painter: _QuizCompanionSilhouettePainter(
                            colors: colors,
                            glowOpacity: glowOpacity,
                          ),
                        ),
                      ),
                      SizedBox(height: avatarGap),
                      Opacity(
                        opacity: textOpacity,
                        child: Text(
                          'Your Quiz Companion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.appTextStyles.labelLarge.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Opacity(
                        opacity: textOpacity,
                        child: Text(
                          'Coming Soon',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.appTextStyles.bodySmall.copyWith(
                            color: colors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuizCompanionGlowPainter extends CustomPainter {
  final AppThemeColors colors;
  final double glowOpacity;

  const _QuizCompanionGlowPainter({
    required this.colors,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              colors.secondary.withValues(alpha: 0.26 * glowOpacity),
              colors.violet.withValues(alpha: 0.18 * glowOpacity),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.48),
              radius: size.width * 0.48,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.48),
      size.width * 0.40,
      glowPaint,
    );

    final linePaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.14 * glowOpacity)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.24),
      Offset(size.width * 0.82, size.height * 0.24),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.78),
      Offset(size.width * 0.76, size.height * 0.78),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_QuizCompanionGlowPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}

class _QuizCompanionSilhouettePainter extends CustomPainter {
  final AppThemeColors colors;
  final double glowOpacity;

  const _QuizCompanionSilhouettePainter({
    required this.colors,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              colors.secondary.withValues(alpha: 0.36 * glowOpacity),
              colors.violet.withValues(alpha: 0.18 * glowOpacity),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.55),
          );

    canvas.drawCircle(center, size.shortestSide * 0.48, haloPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [colors.secondary, colors.violet],
      ).createShader(Offset.zero & size);

    final fillPaint = Paint()
      ..color = colors.primaryDark.withValues(alpha: 0.32);

    final head = Rect.fromCircle(
      center: Offset(size.width * 0.5, size.height * 0.34),
      radius: size.shortestSide * 0.13,
    );
    canvas.drawOval(head, fillPaint);
    canvas.drawOval(head, strokePaint);

    final body = Path()
      ..moveTo(size.width * 0.28, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.54,
        size.width * 0.50,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.54,
        size.width * 0.72,
        size.height * 0.76,
      );
    canvas.drawPath(body, strokePaint);

    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.34),
        width: size.width * 0.25,
        height: size.height * 0.08,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      visor,
      Paint()..color = colors.secondary.withValues(alpha: 0.34 * glowOpacity),
    );
  }

  @override
  bool shouldRepaint(_QuizCompanionSilhouettePainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}

class _McqHeader extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final double progress;
  final int coins;

  const _McqHeader({
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
    required this.coins,
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.coinGold.withValues(alpha: 0.12),
                borderRadius: AppDimensions.radiusSm,
                border: Border.all(
                  color: AppColors.coinGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: AppColors.coinGold,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    child: Text(
                      '$coins',
                      key: ValueKey(coins),
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
