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
    if (widget.isPreviewMode) _startTimer();
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
    if (widget.isLiveMode) {
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
    final colors = context.themeColors;
    final feedback = _effectiveFeedback;
    final hiddenOptionIds = _effectiveHiddenOptionIds;
    final selectedOptionId = _effectiveSelectedOptionId;
    final isInteractionLocked = _isInteractionLocked;
    // A hint is "shown" once the player spends it (preview) or as soon as the
    // server ships one on the question frame (live).
    final showHint =
        _effectiveHintUsed || widget.hint != null || widget.hintText != null;

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
                            _SuddenDeathTopBar(
                              energy: widget.energy,
                              coins: widget.coins,
                              isPreviewMode: widget.isPreviewMode,
                              onExit: widget.onExit,
                            ),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            _SuddenDeathStatusRow(
                              currentIndex: widget.currentIndex,
                              totalQuestions: widget.totalQuestions,
                              currentStreak: widget.currentStreak,
                              bestStreak: widget.bestStreak,
                              remainingTime: _remainingTime,
                              timeLimit: SuddenDeathConfig.questionTimeLimit,
                              showTimeBoost: _showTimeBoost,
                            ),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            FadeTransition(
                              opacity: _entryController.drive(
                                CurveTween(curve: AppMotion.easeOut),
                              ),
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0, -0.035),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _entryController,
                                        curve: AppMotion.easeOut,
                                        reverseCurve: AppMotion.easeIn,
                                      ),
                                    ),
                                child: _QuestionPanel(
                                  question: widget.question,
                                  selectedOptionId: selectedOptionId,
                                  hiddenOptionIds: hiddenOptionIds,
                                  feedback: feedback,
                                  feedbackAnimation: _feedbackController,
                                  serverAnswerResult: widget.serverAnswerResult,
                                  onSelected: isInteractionLocked
                                      ? null
                                      : _handleOptionTap,
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: AppMotion.duration(
                                context,
                                AppMotion.normal,
                              ),
                              alignment: Alignment.topCenter,
                              child: showHint
                                  ? Padding(
                                      padding: EdgeInsets.only(
                                        top: AppSpacing.sm,
                                      ),
                                      child: _SuddenDeathHint(
                                        text:
                                            _effectiveHintText ??
                                            'Eliminate choices that do not match the strongest clue in the prompt.',
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(
                              height: isCompact ? AppSpacing.md : AppSpacing.lg,
                            ),
                            const _DangerBanner(),
                            const SizedBox(height: AppSpacing.md),
                            if (!isCompact) const _MascotCallout(),
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
                      child: Column(
                        children: [
                          GamePowerUpBar(
                            coinBalanceOverride: widget.coins,
                            isDisabled: isInteractionLocked,
                            isPreviewMode: widget.isPreviewMode,
                            isDense: constraints.maxWidth < 380,
                            wrapOnCompact: true,
                            actions: [
                              GamePowerUpAction(
                                id: 'sudden-time',
                                label: '+5 SEC',
                                description:
                                    'Add five seconds to this question.',
                                coinCost: 12,
                                icon: Icons.timer_outlined,
                                isUsed: _extraTimeUsed,
                                isDisabled:
                                    widget.isLiveMode &&
                                    widget.onAddTime == null,
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
                                    widget.isLiveMode && widget.onHint == null,
                                onUse: _showHint,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Live mode answers on tap — the server owns the
                          // clock, so there is nothing left to confirm.
                          if (widget.isPreviewMode)
                            AppButton(
                              label: 'Submit',
                              variant: AppButtonVariant.destructive,
                              leadingIcon: const Icon(Icons.bolt_rounded),
                              onPressed:
                                  _selectedOptionId == null ||
                                      isInteractionLocked
                                  ? null
                                  : _submitSelectedAnswer,
                            ),
                        ],
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
  final int energy;
  final int coins;
  final bool isPreviewMode;
  final VoidCallback onExit;

  const _SuddenDeathTopBar({
    required this.energy,
    required this.coins,
    required this.isPreviewMode,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
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
                  if (isPreviewMode) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.14),
                          borderRadius: AppDimensions.radiusSm,
                          border: Border.all(
                            color: colors.warning.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Text(
                          'UI preview',
                          style: context.appTextStyles.labelSmall.copyWith(
                            color: colors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResourceChip(
                icon: Icons.bolt_rounded,
                value: energy,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ResourceChip(
                icon: Icons.monetization_on_rounded,
                value: coins,
                color: AppColors.coinGold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _ResourceChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.16),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.primary.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$value',
            style: context.appTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuddenDeathStatusRow extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int bestStreak;
  final Duration remainingTime;
  final Duration timeLimit;
  final bool showTimeBoost;

  const _SuddenDeathStatusRow({
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.bestStreak,
    required this.remainingTime,
    required this.timeLimit,
    required this.showTimeBoost,
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
            child: _CountdownTimerBadge(
              remainingTime: remainingTime,
              timeLimit: timeLimit,
              showTimeBoost: showTimeBoost,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _HudMetric(
                  label: 'Current streak',
                  value: '$currentStreak',
                  icon: Icons.whatshot_rounded,
                  color: AppColors.streakFire,
                  alignEnd: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Best streak: $bestStreak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.labelLarge.copyWith(
                    color: AppColors.coinGold,
                  ),
                ),
              ],
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

class _CountdownTimerBadge extends StatelessWidget {
  final Duration remainingTime;
  final Duration timeLimit;
  final bool showTimeBoost;

  const _CountdownTimerBadge({
    required this.remainingTime,
    required this.timeLimit,
    required this.showTimeBoost,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final totalSeconds = timeLimit.inSeconds <= 0
        ? 1
        : remainingTime.inSeconds > timeLimit.inSeconds
        ? remainingTime.inSeconds
        : timeLimit.inSeconds;
    final remainingSeconds = remainingTime.inSeconds
        .clamp(0, totalSeconds)
        .toInt();
    final progress = remainingSeconds / totalSeconds;
    final isLowTime = progress <= 0.3;
    final accent = progress <= 0.3
        ? colors.error
        : progress <= 0.5
        ? AppColors.streakFire
        : colors.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isLowTime ? 1 : 0),
      duration: AppMotion.duration(context, AppMotion.normal),
      curve: AppMotion.easeOut,
      builder: (context, pulse, child) {
        return AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.fast),
          scale: isLowTime ? 1.02 : 1,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  key: isLowTime ? const Key('sudden-low-time') : null,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(
                      accent.withValues(alpha: 0.1 + pulse * 0.04),
                      colors.surface,
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.28 + pulse * 0.18),
                    ),
                    boxShadow: isLowTime
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: AppMotion.duration(context, AppMotion.normal),
                    curve: AppMotion.easeOut,
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: colors.border.withValues(alpha: 0.45),
                        color: accent,
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.duration(
                        context,
                        const Duration(milliseconds: 180),
                      ),
                      child: Text(
                        remainingSeconds.toString().padLeft(2, '0'),
                        key: ValueKey(remainingSeconds),
                        style: context.appTextStyles.headingLarge.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'SEC',
                      style: context.appTextStyles.labelSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                AnimatedPositioned(
                  duration: AppMotion.duration(context, AppMotion.normal),
                  curve: AppMotion.easeOut,
                  top: showTimeBoost ? -22 : 4,
                  child: AnimatedOpacity(
                    duration: AppMotion.duration(context, AppMotion.normal),
                    opacity: showTimeBoost ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.16),
                        borderRadius: AppDimensions.radiusSm,
                        border: Border.all(
                          color: colors.success.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        child: Text(
                          '+5 SEC',
                          style: context.appTextStyles.labelSmall.copyWith(
                            color: colors.success,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  final SuddenDeathQuestion question;
  final String? selectedOptionId;
  final Set<String> hiddenOptionIds;
  final SuddenDeathFeedbackState feedback;
  final Animation<double> feedbackAnimation;
  final ValueChanged<String>? onSelected;
  final WsAnswerResultPayload? serverAnswerResult;

  const _QuestionPanel({
    required this.question,
    required this.selectedOptionId,
    required this.hiddenOptionIds,
    required this.feedback,
    required this.feedbackAnimation,
    required this.onSelected,
    this.serverAnswerResult,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    final panel = Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.92),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
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
              const _ChallengeChip(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _topicLabelFromId(question.topicId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTextStyles.labelLarge.copyWith(
              color: colors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            question.prompt,
            style: context.appTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          AnimatedSize(
            duration: AppMotion.duration(context, AppMotion.normal),
            alignment: Alignment.topCenter,
            child: feedback == SuddenDeathFeedbackState.none
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _SurvivalFeedbackBanner(
                      feedback: feedback,
                      animation: feedbackAnimation,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < question.options.length; i++) ...[
            _SuddenDeathOptionEntry(
              index: i,
              child: _AnswerCard(
                label: String.fromCharCode(65 + i),
                option: question.options[i],
                isSelected: selectedOptionId == question.options[i].id,
                isHidden: hiddenOptionIds.contains(question.options[i].id),
                serverAnswerResult: serverAnswerResult,
                feedback: selectedOptionId == question.options[i].id
                    ? feedback
                    : SuddenDeathFeedbackState.none,
                onTap: onSelected == null
                    ? null
                    : () => onSelected!(question.options[i].id),
              ),
            ),
            if (i != question.options.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );

    return AnimatedBuilder(
      animation: feedbackAnimation,
      child: panel,
      builder: (context, child) {
        if (feedback != SuddenDeathFeedbackState.eliminated) return child!;
        final progress = feedbackAnimation.value;
        final horizontalOffset =
            math.sin(progress * math.pi * 6) * (1 - progress) * 6;
        return Transform.translate(
          offset: Offset(horizontalOffset, 0),
          child: child,
        );
      },
    );
  }
}

class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: AppDimensions.radiusSm,
        border: Border.all(color: colors.error.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: colors.error, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Survival run',
            style: context.appTextStyles.labelLarge.copyWith(
              color: colors.error,
            ),
          ),
        ],
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
    final isFailure =
        feedback == SuddenDeathFeedbackState.eliminated ||
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
        scale: Tween<double>(
          begin: 0.96,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.easeOut)),
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

class _AnswerCard extends StatelessWidget {
  final String label;
  final QuestionOption option;
  final bool isSelected;
  final bool isHidden;
  final SuddenDeathFeedbackState feedback;
  final VoidCallback? onTap;

  /// Latest server verdict for the parent question. Used only to reveal the
  /// correct option after the run is decided — the option ids in a live
  /// payload are the server's shuffled letters, which do not necessarily match
  /// the locally mapped ids.
  final WsAnswerResultPayload? serverAnswerResult;

  const _AnswerCard({
    required this.label,
    required this.option,
    required this.isSelected,
    required this.isHidden,
    required this.feedback,
    this.serverAnswerResult,
    this.onTap,
  });

  /// Whether this card is the correct answer, per the server verdict.
  bool _matchesServerCorrect(String? correctOption) {
    if (correctOption == null || correctOption.isEmpty) return false;
    return correctOption.toLowerCase() == label.toLowerCase() ||
        correctOption.toLowerCase() == option.id.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final hasFeedback = feedback != SuddenDeathFeedbackState.none;
    final isFailure =
        feedback == SuddenDeathFeedbackState.eliminated ||
        feedback == SuddenDeathFeedbackState.timeUp;
    final serverRevealsCorrect = _matchesServerCorrect(
      serverAnswerResult?.correctOption,
    );
    final accent = isHidden
        ? colors.textMuted
        : (hasFeedback && (isSelected ? !isFailure : serverRevealsCorrect))
        ? (isFailure && isSelected ? colors.error : colors.success)
        : isSelected
        ? colors.secondary
        : colors.primary;

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
                    onTap: onTap,
                    borderRadius: AppDimensions.radiusMd,
                    child: AnimatedContainer(
                      key: Key('sudden-option-${option.id}'),
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.easeOut,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          accent.withValues(alpha: isSelected ? 0.12 : 0.07),
                          colors.surface,
                        ),
                        borderRadius: AppDimensions.radiusMd,
                        border: Border.all(
                          color: accent.withValues(
                            alpha: isSelected ? 0.88 : 0.28,
                          ),
                          width: isSelected ? 1.6 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 14,
                                ),
                              ]
                            : AppElevation.shadows(colors, 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(
                                alpha: isSelected ? 0.2 : 0.12,
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.72),
                              ),
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
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.fast,
                            ),
                            child: hasFeedback && isSelected
                                ? Icon(
                                    isFailure
                                        ? Icons.cancel_rounded
                                        : Icons.check_circle_rounded,
                                    key: ValueKey(feedback),
                                    color: accent,
                                    size: 28,
                                  )
                                : isSelected
                                ? Icon(
                                    Icons.radio_button_checked_rounded,
                                    key: const ValueKey('selected-neutral'),
                                    color: accent,
                                    size: 26,
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
          ),
        ),
      ),
    );
  }
}

class _DangerBanner extends StatelessWidget {
  const _DangerBanner();

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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.14),
              borderRadius: AppDimensions.radiusMd,
              border: Border.all(color: colors.error.withValues(alpha: 0.44)),
            ),
            child: Icon(Icons.dangerous_rounded, color: colors.error, size: 34),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One wrong answer',
                  style: context.appTextStyles.titleMedium.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Survive each question and build your streak.',
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuddenDeathHint extends StatelessWidget {
  final String text;

  const _SuddenDeathHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: AppDimensions.radiusCard,
        border: Border.all(color: colors.warning.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: colors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
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

class _MascotCallout extends StatelessWidget {
  const _MascotCallout();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: AppDimensions.radiusCard,
              border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
            ),
            child: Text(
              "Don't lose the streak!",
              style: context.appTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 104,
          height: 108,
          child: CustomPaint(painter: _MascotPainter(colors)),
        ),
      ],
    );
  }
}

class _MascotPainter extends CustomPainter {
  final AppThemeColors colors;

  const _MascotPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.42, size.height * 0.64);
    final firePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.streakFire.withValues(alpha: 0.36),
              colors.violet.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.58),
          );
    canvas.drawCircle(center, size.width * 0.48, firePaint);

    final bodyPaint = Paint()..color = colors.primary.withValues(alpha: 0.86);
    final facePaint = Paint()..color = colors.surface;
    final eyePaint = Paint()..color = colors.textPrimary;
    final goldPaint = Paint()..color = AppColors.coinGold;
    final signPaint = Paint()..color = colors.violet.withValues(alpha: 0.9);

    final platformRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.78,
        size.width * 0.62,
        12,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(platformRect, Paint()..color = colors.primaryDark);

    canvas.drawCircle(center, size.width * 0.23, bodyPaint);
    canvas.drawCircle(
      Offset(center.dx, center.dy - 3),
      size.width * 0.2,
      facePaint,
    );

    canvas.drawCircle(
      Offset(center.dx - size.width * 0.07, center.dy - size.height * 0.03),
      5,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.07, center.dy - size.height * 0.03),
      5,
      eyePaint,
    );
    canvas.drawCircle(Offset(center.dx, center.dy + 7), 3, eyePaint);

    final crown = Path()
      ..moveTo(center.dx - 18, center.dy - 23)
      ..lineTo(center.dx - 12, center.dy - 40)
      ..lineTo(center.dx - 2, center.dy - 25)
      ..lineTo(center.dx + 8, center.dy - 42)
      ..lineTo(center.dx + 17, center.dy - 23)
      ..close();
    canvas.drawPath(crown, goldPaint);

    final polePaint = Paint()
      ..color = colors.textPrimary.withValues(alpha: 0.72)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final poleStart = Offset(center.dx + size.width * 0.2, center.dy + 22);
    final poleEnd = Offset(center.dx + size.width * 0.34, center.dy - 42);
    canvas.drawLine(poleStart, poleEnd, polePaint);

    final signPath = Path()
      ..moveTo(poleEnd.dx - 4, poleEnd.dy - 4)
      ..lineTo(poleEnd.dx + 48, poleEnd.dy + 4)
      ..lineTo(poleEnd.dx + 42, poleEnd.dy + 34)
      ..lineTo(poleEnd.dx - 10, poleEnd.dy + 26)
      ..close();
    canvas.drawPath(signPath, signPaint);
  }

  @override
  bool shouldRepaint(_MascotPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

String _topicLabelFromId(String topicId) {
  final words = topicId
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .toList();
  if (words.isEmpty) return 'Challenge';
  return words.take(2).join(' ');
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
