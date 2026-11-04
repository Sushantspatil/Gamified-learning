import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_header.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/domain/rewards_models.dart';
import 'game_power_up_bar.dart';
import '../../../character/application/character_controller.dart';
import '../../../character/presentation/character_providers.dart';
import '../../../character/presentation/character_stage.dart';
import '../../../character/presentation/mcq_character_adapter.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';
import '../../../character/presentation/character_speech_bubble.dart';

class McqQuestionView extends ConsumerStatefulWidget {
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
  ConsumerState<McqQuestionView> createState() => _McqQuestionViewState();
}

class _McqQuestionViewState extends ConsumerState<McqQuestionView>
    with SingleTickerProviderStateMixin {
  static const String _skippedOptionId = '__mcq_skipped__';

  late final AnimationController _questionMotionController;
  String? _selectedOptionId;
  Set<String> _hiddenOptionIds = {};
  bool _isFiftyFiftyUsed = false;
  bool _isHintVisible = false;
  bool _isSkipUsed = false;
  bool _isSubmitted = false;

  late final McqCharacterAdapter _character;

  /// Moves the 3D character along its strip: it walks in for each question,
  /// hops when an option is picked and runs off when the answer is submitted.
  final Character3dController _character3d = Character3dController();

  /// Tells the character a question appeared (after the frame, so listeners
  /// are never notified mid-build).
  void _announceQuestion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _character.questionShown(isFirst: widget.currentIndex == 0);
      _character3d.enter(thenThink: true);
    });
  }

  bool get _isFinalQuestion => widget.currentIndex >= widget.totalQuestions - 1;

  @override
  void initState() {
    super.initState();
    _character = McqCharacterAdapter(ref.read(characterControllerProvider));
    _announceQuestion();
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
      _announceQuestion();
    }
  }

  @override
  void dispose() {
    _questionMotionController.dispose();
    super.dispose();
  }

  void _useFiftyFifty() {
    if (_isSubmitted || _isFiftyFiftyUsed) return;
    ref.read(gameAudioServiceProvider).play(GameSound.powerUp);

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
    ref.read(gameAudioServiceProvider).play(GameSound.powerUp);
    setState(() => _isHintVisible = true);
  }

  // ---- Reward tokens (bought in the Shop) ----------------------------

  /// Only a hint the question really has; never a made-up one.
  bool get _canUseHintToken =>
      !_isSubmitted && !_isHintVisible && widget.question.hint != null;

  /// Needs 4+ options so exactly two wrong ones go and two remain.
  bool get _canUseFiftyFiftyToken =>
      !_isSubmitted &&
      !_isFiftyFiftyUsed &&
      widget.question.options.length >= 4;

  void _useHintToken() {
    if (!_canUseHintToken) return;
    final rewards = ref.read(rewardsProvider.notifier);
    if (ref.read(rewardsProvider).powerUpCount(PowerUpType.hint) <= 0) return;
    _showHint(); // shows the question's own hint
    if (_isHintVisible) rewards.consumePowerUp(PowerUpType.hint);
  }

  void _useFiftyFiftyToken() {
    if (!_canUseFiftyFiftyToken) return;
    final rewards = ref.read(rewardsProvider.notifier);
    final owned = ref
        .read(rewardsProvider)
        .powerUpCount(PowerUpType.fiftyFifty);
    if (owned <= 0) return;
    _useFiftyFifty(); // removes exactly two wrong options
    if (_isFiftyFiftyUsed) rewards.consumePowerUp(PowerUpType.fiftyFifty);
  }

  void _skipQuestion() {
    if (_isSubmitted || _isSkipUsed) return;
    ref.read(gameAudioServiceProvider).play(GameSound.skip);
    setState(() => _isSkipUsed = true);
    _submitAnswer(_skippedOptionId);
  }

  Future<void> _submitSelectedAnswer() async {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null) return;
    if (!_isFinalQuestion) {
      ref.read(gameAudioServiceProvider).play(GameSound.nextQuestion);
    }
    await _submitAnswer(selectedOptionId);
  }

  Future<void> _submitAnswer(String selectedOptionId) async {
    if (_isSubmitted) return;

    setState(() => _isSubmitted = true);
    _character.answerSubmitted(isFinal: _isFinalQuestion);
    _character3d.exit();
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
    final character = ref.watch(characterControllerProvider);
    final equipped = ref.watch(
      rewardsProvider.select((s) => (s.equippedAvatar, s.equippedFrame)),
    );
    final cosmetics = Character3dCosmetics.fromShopIds(
      avatarId: equipped.$1,
      frameId: equipped.$2,
    );
    final hintTokens = ref.watch(
      rewardsProvider.select((s) => s.powerUpCount(PowerUpType.hint)),
    );
    final fiftyFiftyTokens = ref.watch(
      rewardsProvider.select((s) => s.powerUpCount(PowerUpType.fiftyFifty)),
    );
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
        GameHeader(
          title: 'MCQ Quiz',
          currentIndex: widget.currentIndex,
          totalQuestions: widget.totalQuestions,
          progress: progress,
          coins: widget.coins,
          semanticLabel: 'MCQ progress',
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final companionHeight = _companionHeightFor(
                constraints.maxHeight,
              );

              Widget animated(Widget child) => FadeTransition(
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
                  child: child,
                ),
              );

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      animated(
                        Text(
                          widget.question.prompt,
                          softWrap: true,
                          style: context.appTextStyles.titleLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Not inside the fade/slide: a WebView must not be
                      // faded or moved by the question transition.
                      _CharacterSlot(
                        controller: character,
                        character3d: _character3d,
                        cosmetics: cosmetics,
                        height: companionHeight,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      animated(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      _hiddenOptionIds.contains(
                                        indexed.$2.id,
                                      )) {
                                    return;
                                  }
                                  ref
                                      .read(gameAudioServiceProvider)
                                      .play(GameSound.answerSelect);
                                  if (_selectedOptionId != indexed.$2.id) {
                                    _character3d.hop();
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
                            _TokenRow(
                              hintTokens: hintTokens,
                              fiftyFiftyTokens: fiftyFiftyTokens,
                              canUseHint: _canUseHintToken,
                              canUseFiftyFifty: _canUseFiftyFiftyToken,
                              onHint: _useHintToken,
                              onFiftyFifty: _useFiftyFiftyToken,
                              hintNote:
                                  hintTokens > 0 && widget.question.hint == null
                                  ? "This question has no hint."
                                  : null,
                              fiftyFiftyNote:
                                  fiftyFiftyTokens > 0 &&
                                      widget.question.options.length < 4
                                  ? "50/50 is not available for this question."
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            submitButton,
                          ],
                        ),
                      ),
                    ],
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
    final promptPenalty = widget.question.prompt.length > 80 ? 32.0 : 0.0;
    return (targetHeight - promptPenalty).clamp(90.0, 200.0);
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
                  softWrap: true,
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

/// Reserved area for the host character and its speech bubble, between the
/// question and the options. Hidden in landscape where there is no room.
class _CharacterSlot extends StatelessWidget {
  final CharacterController controller;
  final Character3dController character3d;
  final Character3dCosmetics cosmetics;
  final double height;

  const _CharacterSlot({
    required this.controller,
    required this.character3d,
    required this.cosmetics,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      key: const Key('mcq_character_section'),
      height: height,
      // The 3D character walks along the strip. Nothing shows while it loads
      // (it simply walks in when ready); if it cannot run, the original 2D host
      // is shown instead.
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            // A pool of light on the floor under the spot where it stands.
            Positioned.fill(
              child: ValueListenableBuilder<Character3dStatus>(
                valueListenable: character3d.status,
                builder: (context, status, _) =>
                    status == Character3dStatus.ready
                    ? const CharacterGlow.floor(
                        strength: 0.9,
                        child: SizedBox(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Character3dView(
              width: constraints.maxWidth,
              height: height,
              state: Character3dState.idle,
              framing: Character3dFraming.strip,
              controller: character3d,
              cosmetics: cosmetics,
              placeholder: const SizedBox.shrink(),
              fallback: SizedBox(
                width: constraints.maxWidth,
                height: height,
                child: CharacterStage(controller: controller, height: height),
              ),
            ),
            // The host's short, neutral lines, beside the 3D character (the 2D
            // fallback draws its own bubble).
            ValueListenableBuilder<Character3dStatus>(
              valueListenable: character3d.status,
              builder: (context, status, _) {
                if (status != Character3dStatus.ready) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: 2,
                  left: constraints.maxWidth / 2 + 44,
                  right: 4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CharacterSpeechBubble(controller: controller),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shop tokens the student owns, shown only when there is at least one.
/// A token is spent only after its effect has been applied.
class _TokenRow extends StatelessWidget {
  final int hintTokens;
  final int fiftyFiftyTokens;
  final bool canUseHint;
  final bool canUseFiftyFifty;
  final VoidCallback onHint;
  final VoidCallback onFiftyFifty;
  final String? hintNote;
  final String? fiftyFiftyNote;

  const _TokenRow({
    required this.hintTokens,
    required this.fiftyFiftyTokens,
    required this.canUseHint,
    required this.canUseFiftyFifty,
    required this.onHint,
    required this.onFiftyFifty,
    this.hintNote,
    this.fiftyFiftyNote,
  });

  @override
  Widget build(BuildContext context) {
    if (hintTokens == 0 && fiftyFiftyTokens == 0) {
      return const SizedBox.shrink();
    }
    final styles = context.appTextStyles;
    final colors = context.themeColors;
    final notes = [?hintNote, ?fiftyFiftyNote];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (hintTokens > 0)
                OutlinedButton.icon(
                  key: const Key('use_hint_token'),
                  onPressed: canUseHint ? onHint : null,
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text('Hint Token x$hintTokens'),
                ),
              if (fiftyFiftyTokens > 0)
                OutlinedButton.icon(
                  key: const Key('use_fifty_fifty_token'),
                  onPressed: canUseFiftyFifty ? onFiftyFifty : null,
                  icon: const Icon(Icons.filter_2, size: 18),
                  label: Text('50/50 Token x$fiftyFiftyTokens'),
                ),
            ],
          ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                note,
                style: styles.caption.copyWith(color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
