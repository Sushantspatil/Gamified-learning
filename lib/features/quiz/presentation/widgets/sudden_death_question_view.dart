import 'dart:async';
import 'dart:math' as math;

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

import '../../data/models/sudden_death_ws_dto.dart';

class SuddenDeathConfig {
  SuddenDeathConfig._();

  static const Duration questionTimeLimit = Duration(seconds: 15);
}

enum SuddenDeathFeedbackState { none, survived, eliminated, timeUp, skipped }

class SuddenDeathQuestionView extends StatefulWidget {
  final SuddenDeathQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int bestStreak;
  final int energy;
  final int coins;
  final VoidCallback onExit;

  /// Preview/local-simulation answer sink. Only used when [isPreviewMode] is
  /// true; the live WebSocket flow answers via [onSelectOption] instead.
  final void Function(Answer answer)? onSubmit;

  /// Live-mode answer sink. Tapping an option submits it straight to the
  /// server, which grades the answer and answers with `answer_result`.
  final void Function(String optionId)? onSelectOption;
  final VoidCallback? onSkip;
  final VoidCallback? onTimeout;
  final VoidCallback? onAddTime;
  final VoidCallback? onFiftyFifty;
  final VoidCallback? onHint;
  final Set<String> hiddenOptionIds;
  final String? hintText;
  final Duration? remainingTime;
  final SuddenDeathFeedbackState feedback;
  final bool isSubmitting;
  final bool isPreviewMode;

  // --- Live (server-authoritative) inputs -------------------------------
  // In live mode the WebSocket session owns the clock, the 50:50 elimination
  // set, which power-ups are spent and whether the run is over. These mirror
  // `SuddenDeathViewState` and are ignored while [isPreviewMode] is true.

  /// Authoritative countdown for the current question, in milliseconds.
  /// The server only pushes this on `question` frames and on resync, so the
  /// widget interpolates locally between updates.
  final int? remainingTimeMs;

  /// Option ids eliminated by the server (50:50 via `power_up_result`).
  final Set<String>? externalHiddenOptionIds;
  final bool externalFiftyFiftyUsed;
  final bool externalSkipUsed;
  final bool externalHintUsed;

  /// Option id the server has recorded for this question, if any.
  final String? externalSelectedOptionId;

  /// Hint text supplied by the server for the current question.
  final String? hint;

  /// Latest `answer_result` frame, used to drive survival feedback and to
  /// reveal the correct option once the run is decided.
  final WsAnswerResultPayload? serverAnswerResult;

  const SuddenDeathQuestionView({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.bestStreak,
    required this.energy,
    required this.coins,
    required this.onExit,
    this.onSubmit,
    this.onSelectOption,
    this.onSkip,
    this.onTimeout,
    this.onAddTime,
    this.onFiftyFifty,
    this.onHint,
    this.hiddenOptionIds = const {},
    this.hintText,
    this.remainingTime,
    this.feedback = SuddenDeathFeedbackState.none,
    this.isSubmitting = false,
    this.isPreviewMode = false,
    this.remainingTimeMs,
    this.externalHiddenOptionIds,
    this.externalFiftyFiftyUsed = false,
    this.externalSkipUsed = false,
    this.externalHintUsed = false,
    this.externalSelectedOptionId,
    this.hint,
    this.serverAnswerResult,
  });

  /// True when this widget renders a live WebSocket session rather than the
  /// local mock preview. Live mode never invents state locally: everything
  /// that affects scoring or the outcome comes from the server.
  bool get isLiveMode => !isPreviewMode;

  @override
  State<SuddenDeathQuestionView> createState() =>
      _SuddenDeathQuestionViewState();
}

class _SuddenDeathQuestionViewState extends State<SuddenDeathQuestionView>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _feedbackController;
  Timer? _timer;
  Timer? _timeBoostTimer;
  String? _selectedOptionId;
  Set<String> _previewHiddenOptionIds = const {};
  Duration _remainingTime = SuddenDeathConfig.questionTimeLimit;
  SuddenDeathFeedbackState _previewFeedback = SuddenDeathFeedbackState.none;
  bool _showTimeBoost = false;
  bool _hasSubmitted = false;
  bool _extraTimeUsed = false;
  bool _fiftyFiftyUsed = false;
  bool _skipUsed = false;
  bool _hintUsed = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 190),
    )..forward();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _remainingTime = _initialRemainingTime;
    _startTimer();
  }

  /// Resolves the starting countdown. Live mode trusts the server's
  /// `remaining_time_ms`; preview mode falls back to the configured limit.
  Duration get _initialRemainingTime {
    if (widget.remainingTimeMs != null) {
      return Duration(milliseconds: widget.remainingTimeMs!);
    }
    return widget.remainingTime ?? SuddenDeathConfig.questionTimeLimit;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entryController.duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 240),
    );
    _entryController.reverseDuration = AppMotion.duration(
      context,
      const Duration(milliseconds: 190),
    );
    _feedbackController.duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(covariant SuddenDeathQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _selectedOptionId = null;
      _previewHiddenOptionIds = const {};
      _hasSubmitted = false;
      _extraTimeUsed = false;
      _fiftyFiftyUsed = false;
      _skipUsed = false;
      _hintUsed = false;
      _previewFeedback = SuddenDeathFeedbackState.none;
      _showTimeBoost = false;
      _remainingTime = _initialRemainingTime;
      _feedbackController.reset();
      _entryController.forward(from: 0);
      _startTimer();
    } else if (widget.isLiveMode &&
        widget.remainingTimeMs != oldWidget.remainingTimeMs) {
      // The server re-seeded the clock (new question or `join_game` resync).
      // Trust it over our locally interpolated value.
      _remainingTime = _initialRemainingTime;
    } else if (!widget.isPreviewMode &&
        widget.remainingTime != null &&
        widget.remainingTime != oldWidget.remainingTime) {
      _remainingTime = widget.remainingTime!;
    }

    if (widget.feedback != oldWidget.feedback &&
        widget.feedback != SuddenDeathFeedbackState.none) {
      _feedbackController.forward(from: 0);
    }

    // Live mode drives the survival banner off the server's `answer_result`.
    if (widget.serverAnswerResult != null &&
        !identical(widget.serverAnswerResult, oldWidget.serverAnswerResult)) {
      _feedbackController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeBoostTimer?.cancel();
    _entryController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isInteractionLocked) return;

      final nextRemaining = _remainingTime - const Duration(seconds: 1);
      if (nextRemaining <= Duration.zero) {
        setState(() => _remainingTime = Duration.zero);
        _timer?.cancel();
        if (widget.isPreviewMode) {
          _submitTimeout();
        } else {
          widget.onTimeout?.call();
        }
        return;
      }

      setState(() => _remainingTime = nextRemaining);
    });
  }

  // --- Derived state ----------------------------------------------------
  // Live mode never trusts locally mirrored flags; everything below is read
  // from the server-owned state so the UI can never disagree with the grader.

  /// Whether the run is decided from the user's side: an answer is in flight
  /// or the server has already graded this question.
  bool get _isServerAnswerPending {
    final result = widget.serverAnswerResult;
    if (result == null) return false;
    if (result.question.isNotEmpty &&
        result.question.toLowerCase() != widget.question.id.toLowerCase()) {
      return false;
    }
    return true;
  }

  bool get _isInteractionLocked => widget.isLiveMode
      ? widget.isSubmitting || _isServerAnswerPending
      : _hasSubmitted ||
            widget.isSubmitting ||
            _previewFeedback != SuddenDeathFeedbackState.none;

  String? get _effectiveSelectedOptionId {
    if (!widget.isLiveMode) return _selectedOptionId;
    final external = widget.externalSelectedOptionId;
    if (external != null) return external;
    return _selectedOptionId;
  }

  Set<String> get _effectiveHiddenOptionIds {
    if (!widget.isLiveMode) return _previewHiddenOptionIds;
    return widget.externalHiddenOptionIds ?? widget.hiddenOptionIds;
  }

  bool get _effectiveFiftyFiftyUsed =>
      _fiftyFiftyUsed || widget.externalFiftyFiftyUsed;

  bool get _effectiveSkipUsed => _skipUsed || widget.externalSkipUsed;

  bool get _effectiveHintUsed => _hintUsed || widget.externalHintUsed;

  /// Survival feedback for the current question.
  ///
  /// Preview mode simulates it locally; live mode derives it from the
  /// server's verdict so the banner can never contradict the score.
  SuddenDeathFeedbackState get _effectiveFeedback {
    if (!widget.isLiveMode) return _previewFeedback;

    final explicit = widget.feedback;
    if (explicit != SuddenDeathFeedbackState.none) return explicit;

    final result = widget.serverAnswerResult;
    if (result == null) return SuddenDeathFeedbackState.none;
    if (result.question.isNotEmpty &&
        result.question.toLowerCase() != widget.question.id.toLowerCase()) {
      return SuddenDeathFeedbackState.none;
    }
    if (result.isTimeout) return SuddenDeathFeedbackState.timeUp;
    if (result.isSkipped) return SuddenDeathFeedbackState.skipped;
    return result.isCorrect
        ? SuddenDeathFeedbackState.survived
        : SuddenDeathFeedbackState.eliminated;
  }

  String? get _effectiveHintText => widget.isLiveMode
      ? widget.hint ?? widget.hintText ?? widget.question.hint
      : widget.hintText ?? widget.question.hint;

  Future<void> _submitTimeout() async {
    if (_hasSubmitted || !widget.isPreviewMode) return;
    setState(() {
      _hasSubmitted = true;
      _previewFeedback = SuddenDeathFeedbackState.timeUp;
    });
    _timer?.cancel();
    await _playFeedbackAndExit();
    if (!mounted) return;
    widget.onTimeout?.call();
  }

  /// Handles an option tap.
  ///
  /// Preview mode stages the selection and waits for the Submit button. Live
  /// mode submits immediately, because the server grades the answer and owns
  /// the countdown — staging a selection would just burn the player's clock.
  void _handleOptionTap(String optionId) {
    if (_isInteractionLocked) return;

    if (widget.isLiveMode) {
      setState(() => _selectedOptionId = optionId);
      widget.onSelectOption?.call(optionId);
      return;
    }

    setState(() => _selectedOptionId = optionId);
  }

  /// Preview-only: grades locally and reports through [SuddenDeathQuestionView.onSubmit].
  Future<void> _submitSelectedAnswer() async {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null || _hasSubmitted) return;

    final isCorrect = selectedOptionId == widget.question.correctOptionId;
    setState(() {
      _hasSubmitted = true;
      _previewFeedback = isCorrect
          ? SuddenDeathFeedbackState.survived
          : SuddenDeathFeedbackState.eliminated;
    });
    _timer?.cancel();
    await _playFeedbackAndExit();
    if (!mounted) return;
    widget.onSubmit?.call(
      SuddenDeathAnswer(
        questionId: widget.question.id,
        selectedOptionId: selectedOptionId,
      ),
    );
  }

  void _addFiveSeconds() {
    if (_isInteractionLocked || _extraTimeUsed) return;
    if (widget.isLiveMode && widget.onAddTime != null) {
      widget.onAddTime?.call();
      return;
    }
    setState(() {
      _extraTimeUsed = true;
      _remainingTime = _remainingTime + const Duration(seconds: 5);
      _showTimeBoost = true;
    });
    _timeBoostTimer?.cancel();
    _timeBoostTimer = Timer(const Duration(milliseconds: 760), () {
      if (mounted) setState(() => _showTimeBoost = false);
    });
  }

  void _useFiftyFifty() {
    if (_isInteractionLocked ||
        _effectiveFiftyFiftyUsed ||
        widget.question.options.length <= 2) {
      return;
    }
    if (widget.isLiveMode) {
      // Mark optimistically; the server's `power_up_result` confirms it.
      setState(() => _fiftyFiftyUsed = true);
      widget.onFiftyFifty?.call();
      return;
    }
    final wrongOptions = widget.question.options
        .where((option) => option.id != widget.question.correctOptionId)
        .toList();
    if (wrongOptions.length < 2) return;

    setState(() {
      _fiftyFiftyUsed = true;
      _previewHiddenOptionIds = wrongOptions
          .take(2)
          .map((option) => option.id)
          .toSet();
      if (_selectedOptionId != null &&
          _previewHiddenOptionIds.contains(_selectedOptionId)) {
        _selectedOptionId = null;
      }
    });
  }

  Future<void> _skipQuestion() async {
    if (_effectiveSkipUsed || widget.onSkip == null) return;
    if (widget.isLiveMode) {
      if (_isInteractionLocked) return;
      setState(() {
        _skipUsed = true;
        _hasSubmitted = true;
      });
      _timer?.cancel();
      widget.onSkip!.call();
      return;
    }
    if (_hasSubmitted) return;
    setState(() {
      _skipUsed = true;
      _hasSubmitted = true;
      _previewFeedback = SuddenDeathFeedbackState.skipped;
    });
    _timer?.cancel();
    await _playFeedbackAndExit();
    if (!mounted) return;
    widget.onSkip!.call();
  }

  void _showHint() {
    if (_effectiveHintUsed) return;
    if (widget.isLiveMode) {
      setState(() => _hintUsed = true);
      widget.onHint?.call();
      return;
    }
    if (_hasSubmitted) return;
    setState(() => _hintUsed = true);
    widget.onHint?.call();
  }

  Future<void> _playFeedbackAndExit() async {
    _feedbackController.forward(from: 0);
    await Future<void>.delayed(AppMotion.duration(context, AppMotion.slow));
    if (!mounted) return;
    unawaited(_entryController.reverse());
    await Future<void>.delayed(
      AppMotion.duration(
        context,
        _entryController.reverseDuration ?? Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _effectiveFeedback;
    final hiddenOptionIds = _effectiveHiddenOptionIds;
    final selectedOptionId = _effectiveSelectedOptionId;
    final isInteractionLocked = _isInteractionLocked;
    final showHint =
        _effectiveHintUsed || widget.hint != null || widget.hintText != null;

    final progress = widget.totalQuestions == 0
        ? 0.0
        : (widget.currentIndex + 1) / widget.totalQuestions;

    final submitButton = AnimatedScale(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      scale: selectedOptionId == null || isInteractionLocked ? 0.98 : 1,
      child: AnimatedOpacity(
        duration: AppMotion.duration(context, AppMotion.fast),
        opacity: selectedOptionId == null || isInteractionLocked ? 0.62 : 1,
        child: AppButton(
          label: 'Submit',
          trailingIcon: const Icon(Icons.arrow_forward_rounded),
          onPressed: selectedOptionId == null || isInteractionLocked
              ? null
              : _submitSelectedAnswer,
        ),
      ),
    );

    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SuddenDeathHeader(
            currentIndex: widget.currentIndex,
            totalQuestions: widget.totalQuestions,
            progress: progress,
            coins: widget.coins,
            currentStreak: widget.currentStreak,
            bestStreak: widget.bestStreak,
            remainingTime: _remainingTime,
            timeLimit: SuddenDeathConfig.questionTimeLimit,
            showTimeBoost: _showTimeBoost,
            onExit: widget.onExit,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: FadeTransition(
                      opacity: _entryController.drive(
                        CurveTween(curve: AppMotion.easeOut),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.045),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _entryController,
                            curve: AppMotion.easeOut,
                            reverseCurve: AppMotion.easeIn,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _feedbackController,
                          builder: (context, child) {
                            if (feedback != SuddenDeathFeedbackState.eliminated) {
                              return child!;
                            }
                            final p = _feedbackController.value;
                            final dx = math.sin(p * math.pi * 6) * (1 - p) * 6;
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.question.prompt,
                                style: context.appTextStyles.titleLarge,
                              ),
                              if (feedback != SuddenDeathFeedbackState.none) ...[
                                const SizedBox(height: AppSpacing.sm),
                                _SurvivalFeedbackBanner(
                                  feedback: feedback,
                                  animation: _feedbackController,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              for (var i = 0;
                                  i < widget.question.options.length;
                                  i++) ...[
                                _SuddenDeathOptionEntry(
                                  index: i,
                                  child: _SuddenDeathOptionCard(
                                    option: widget.question.options[i],
                                    label: String.fromCharCode(65 + i),
                                    isSelected: selectedOptionId ==
                                        widget.question.options[i].id,
                                    isHidden: hiddenOptionIds.contains(
                                      widget.question.options[i].id,
                                    ),
                                    isDisabled: isInteractionLocked,
                                    isCorrect: (widget.question.correctOptionId
                                                .isNotEmpty &&
                                            widget.question.correctOptionId
                                                    .toLowerCase() ==
                                                widget.question.options[i].id
                                                    .toLowerCase()) ||
                                        (widget.serverAnswerResult?.correctOption !=
                                                null &&
                                            (widget.serverAnswerResult!
                                                        .correctOption
                                                        .toLowerCase() ==
                                                    String.fromCharCode(65 + i)
                                                        .toLowerCase() ||
                                                widget.serverAnswerResult!
                                                        .correctOption
                                                        .toLowerCase() ==
                                                    widget.question.options[i].id
                                                        .toLowerCase())),
                                    feedback: feedback,
                                    serverAnswerResult:
                                        widget.serverAnswerResult,
                                    onSelected: () => _handleOptionTap(
                                      widget.question.options[i].id,
                                    ),
                                  ),
                                ),
                                if (i != widget.question.options.length - 1)
                                  const SizedBox(height: AppSpacing.sm),
                              ],
                              AnimatedSize(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.normal,
                                ),
                                alignment: Alignment.topCenter,
                                child: showHint
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.md,
                                        ),
                                        child: _HintPanel(
                                          text: _effectiveHintText ??
                                              'Eliminate choices that do not match the strongest clue in the prompt.',
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GamePowerUpBar(
                                coinBalanceOverride: widget.coins,
                                isDisabled: isInteractionLocked,
                                actions: [
                                  GamePowerUpAction(
                                    id: 'sudden-time',
                                    label: '+5 SEC',
                                    description:
                                        'Add five seconds to this question.',
                                    coinCost: 12,
                                    icon: Icons.timer_outlined,
                                    isUsed: _extraTimeUsed,
                                    isDisabled: _extraTimeUsed,
                                    onUse: _addFiveSeconds,
                                  ),
                                  GamePowerUpAction(
                                    id: 'sudden-50-50',
                                    label: '50:50',
                                    description: widget.question.options.length <= 2
                                        ? 'Not available for 2-choice questions.'
                                        : 'Hide two wrong answers.',
                                    coinCost: 25,
                                    icon: Icons.call_split_rounded,
                                    isUsed: _effectiveFiftyFiftyUsed,
                                    isDisabled:
                                        widget.question.options.length <= 2 ||
                                        (widget.isLiveMode &&
                                            widget.onFiftyFifty == null),
                                    onUse: _useFiftyFifty,
                                  ),
                                  GamePowerUpAction(
                                    id: 'sudden-skip',
                                    label: 'Skip',
                                    description: 'Skip this question safely.',
                                    coinCost: 35,
                                    icon: Icons.fast_forward_rounded,
                                    isUsed: _effectiveSkipUsed,
                                    isDisabled: widget.onSkip == null,
                                    onUse: _skipQuestion,
                                  ),
                                  GamePowerUpAction(
                                    id: 'sudden-hint',
                                    label: 'Hint',
                                    description:
                                        'Show a clue without ending the run.',
                                    coinCost: 10,
                                    icon: Icons.lightbulb_outline,
                                    isUsed: showHint,
                                    isDisabled:
                                        widget.isLiveMode &&
                                        widget.onHint == null,
                                    onUse: _showHint,
                                  ),
                                ],
                              ),
                              if (widget.isPreviewMode) ...[
                                const SizedBox(height: AppSpacing.md),
                                submitButton,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuddenDeathHeader extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final double progress;
  final int coins;
  final int currentStreak;
  final int bestStreak;
  final Duration remainingTime;
  final Duration timeLimit;
  final bool showTimeBoost;
  final VoidCallback onExit;

  const _SuddenDeathHeader({
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
    required this.coins,
    required this.currentStreak,
    required this.bestStreak,
    required this.remainingTime,
    required this.timeLimit,
    required this.showTimeBoost,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final remainingSeconds = remainingTime.inSeconds.clamp(0, 99).toInt();
    final isLowTime = remainingSeconds <= 4;
    final timeColor = isLowTime
        ? colors.error
        : remainingSeconds <= 8
        ? AppColors.streakFire
        : colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Tooltip(
              message: 'Exit',
              child: AppPressable(
                onTap: onExit,
                borderRadius: AppDimensions.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.streakFire,
              size: 20,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Sudden Death',
                style: context.appTextStyles.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
                  fontWeight: FontWeight.w700,
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
              semanticLabel: 'Sudden Death progress',
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.streakFire.withValues(alpha: 0.12),
                borderRadius: AppDimensions.radiusSm,
                border: Border.all(
                  color: AppColors.streakFire.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.whatshot_rounded,
                    color: AppColors.streakFire,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak Streak',
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: AppColors.streakFire,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (bestStreak > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(Best: $bestStreak)',
                      style: context.appTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  key: isLowTime ? const Key('sudden-low-time') : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: timeColor.withValues(alpha: isLowTime ? 0.22 : 0.12),
                    borderRadius: AppDimensions.radiusSm,
                    border: Border.all(
                      color: timeColor.withValues(
                        alpha: isLowTime ? 0.75 : 0.35,
                      ),
                      width: isLowTime ? 1.5 : 1,
                    ),
                    boxShadow: isLowTime
                        ? [
                            BoxShadow(
                              color: colors.error.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: timeColor, size: 14),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: AppMotion.duration(
                          context,
                          const Duration(milliseconds: 180),
                        ),
                        child: Text(
                          '$remainingSeconds',
                          key: ValueKey(remainingSeconds),
                          style: context.appTextStyles.labelLarge.copyWith(
                            color: timeColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        's',
                        style: context.appTextStyles.labelSmall.copyWith(
                          color: timeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showTimeBoost)
                  Positioned(
                    top: -14,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.streakFire,
                        borderRadius: AppDimensions.radiusSm,
                      ),
                      child: Text(
                        '+5s',
                        style: context.appTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SuddenDeathOptionEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _SuddenDeathOptionEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.48);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.duration(
        context,
        Duration(milliseconds: 210 + index * 35),
      ),
      curve: Interval(start, 1, curve: AppMotion.easeOut),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SuddenDeathOptionCard extends StatelessWidget {
  final QuestionOption option;
  final String label;
  final bool isSelected;
  final bool isHidden;
  final bool isDisabled;
  final bool isCorrect;
  final SuddenDeathFeedbackState feedback;
  final WsAnswerResultPayload? serverAnswerResult;
  final VoidCallback onSelected;

  const _SuddenDeathOptionCard({
    required this.option,
    required this.label,
    required this.isSelected,
    required this.isHidden,
    required this.isDisabled,
    required this.isCorrect,
    required this.feedback,
    required this.serverAnswerResult,
    required this.onSelected,
  });

  bool _matchesServerCorrect(String? correctOption) {
    if (correctOption == null || correctOption.isEmpty) return false;
    return correctOption.toLowerCase() == label.toLowerCase() ||
        correctOption.toLowerCase() == option.id.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final hasFeedback = feedback != SuddenDeathFeedbackState.none;
    final isFailure = feedback == SuddenDeathFeedbackState.eliminated ||
        feedback == SuddenDeathFeedbackState.timeUp;
    final effectiveIsCorrect =
        isCorrect || _matchesServerCorrect(serverAnswerResult?.correctOption);

    final Color accent;
    if (isHidden) {
      accent = colors.textMuted;
    } else if (hasFeedback) {
      if (isSelected) {
        accent = isFailure ? colors.error : colors.success;
      } else if (isFailure && effectiveIsCorrect) {
        accent = colors.success;
      } else {
        accent = colors.textMuted.withValues(alpha: 0.35);
      }
    } else if (isSelected) {
      accent = colors.primary;
    } else {
      accent = colors.borderStrong;
    }

    final isHighlighted =
        isSelected || (hasFeedback && isFailure && effectiveIsCorrect);

    return Semantics(
      button: true,
      selected: isSelected,
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
                : AppPressable(
                    onTap: isDisabled ? null : onSelected,
                    borderRadius: AppDimensions.radiusMd,
                    pressedScale: 0.98,
                    child: AnimatedContainer(
                      key: Key('sudden-option-${option.id}'),
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.easeOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (hasFeedback
                                ? (isFailure
                                    ? colors.error.withValues(alpha: 0.12)
                                    : colors.success.withValues(alpha: 0.12))
                                : colors.primary.withValues(alpha: 0.08))
                            : (hasFeedback && isFailure && effectiveIsCorrect
                                ? colors.success.withValues(alpha: 0.12)
                                : colors.surface),
                        borderRadius: AppDimensions.radiusMd,
                        border: Border.all(
                          color: isHighlighted ? accent : colors.borderStrong,
                          width: isHighlighted ? 1.5 : 1,
                        ),
                        boxShadow: [
                          ...AppElevation.shadows(colors, 1),
                          if (isHighlighted)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 14,
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
                              duration: AppMotion.duration(
                                context,
                                AppMotion.fast,
                              ),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isSelected ||
                                        (hasFeedback &&
                                            isFailure &&
                                            effectiveIsCorrect)
                                    ? accent.withValues(alpha: 0.16)
                                    : colors.background,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isHighlighted
                                      ? accent
                                      : colors.borderStrong,
                                  width: isHighlighted ? 2.2 : 1.4,
                                ),
                              ),
                              child: Center(
                                child: hasFeedback &&
                                        (isSelected || effectiveIsCorrect)
                                    ? Icon(
                                        (isSelected && isFailure)
                                            ? Icons.close_rounded
                                            : Icons.check_rounded,
                                        size: 13,
                                        color: accent,
                                      )
                                    : AnimatedContainer(
                                        duration: AppMotion.duration(
                                          context,
                                          AppMotion.fast,
                                        ),
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
                                style: context.appTextStyles.bodyMedium
                                    .copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (hasFeedback) ...[
                              const SizedBox(width: AppSpacing.xs),
                              if (isSelected && isFailure)
                                Icon(
                                  Icons.cancel_rounded,
                                  color: colors.error,
                                  size: 22,
                                )
                              else if ((isSelected && !isFailure) ||
                                  (isFailure && effectiveIsCorrect))
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.success,
                                  size: 22,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SurvivalFeedbackBanner extends StatelessWidget {
  final SuddenDeathFeedbackState feedback;
  final Animation<double> animation;

  const _SurvivalFeedbackBanner({
    required this.feedback,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isFailure = feedback == SuddenDeathFeedbackState.eliminated ||
        feedback == SuddenDeathFeedbackState.timeUp;
    final label = switch (feedback) {
      SuddenDeathFeedbackState.survived => 'Survived',
      SuddenDeathFeedbackState.eliminated => 'Eliminated',
      SuddenDeathFeedbackState.timeUp => "Time's up",
      SuddenDeathFeedbackState.skipped => 'Skipped',
      SuddenDeathFeedbackState.none => '',
    };
    final isSkipped = feedback == SuddenDeathFeedbackState.skipped;
    final icon = isFailure
        ? Icons.dangerous_rounded
        : isSkipped
        ? Icons.fast_forward_rounded
        : Icons.shield_rounded;
    final color = isFailure
        ? colors.error
        : isSkipped
        ? colors.warning
        : colors.success;

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppDimensions.radiusMd,
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: context.appTextStyles.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
