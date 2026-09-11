import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/animated_count_text.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../streaks/presentation/providers/streak_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import 'game_power_up_bar.dart';

class MatchTheFollowingView extends ConsumerStatefulWidget {
  final MatchTheFollowingQuestion question;
  final void Function(Answer answer) onSubmit;
  final VoidCallback? onExit;
  final int? coinBalanceOverride;
  final int currentIndex;
  final int totalQuestions;

  const MatchTheFollowingView({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onExit,
    this.coinBalanceOverride,
    this.currentIndex = 0,
    this.totalQuestions = 1,
  }) : assert(currentIndex >= 0),
       assert(totalQuestions > 0);

  @override
  ConsumerState<MatchTheFollowingView> createState() =>
      _MatchTheFollowingViewState();
}

class _MatchTheFollowingViewState extends ConsumerState<MatchTheFollowingView>
    with TickerProviderStateMixin {
  static const double _cardHeight = 64;
  static const double _rowGap = 12;
  static const double _connectorGap = 72;

  late List<MatchPair> _shuffledRight;
  late final AnimationController _entryController;
  late final AnimationController _connectorController;
  late final AnimationController _resultController;

  final _boardKey = GlobalKey();
  final Map<String, GlobalKey> _leftAnchorKeys = {};
  final Map<String, GlobalKey> _rightAnchorKeys = {};
  final Map<String, String> _matches = {};
  Map<String, Offset> _leftAnchors = {};
  Map<String, Offset> _rightAnchors = {};
  bool _measurementScheduled = false;

  String? _selectedLeftPairId;
  _MatchFlowPhase _phase = _MatchFlowPhase.playing;
  bool _isHintVisible = false;
  bool _isAutoMatchUsed = false;
  bool _isShuffleUsed = false;

  @override
  void initState() {
    super.initState();
    _shuffledRight = List.of(widget.question.pairs);
    _shuffledRight.shuffle(Random(widget.question.id.hashCode));
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..forward();
    _connectorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entryController.duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 460),
    );
    _connectorController.duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 280),
    );
    _resultController.duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(covariant MatchTheFollowingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _shuffledRight = List.of(widget.question.pairs);
      _shuffledRight.shuffle(Random(widget.question.id.hashCode));
      _matches.clear();
      _selectedLeftPairId = null;
      _phase = _MatchFlowPhase.playing;
      _isHintVisible = false;
      _isAutoMatchUsed = false;
      _isShuffleUsed = false;
      _leftAnchorKeys.clear();
      _rightAnchorKeys.clear();
      _leftAnchors = {};
      _rightAnchors = {};
      _entryController.forward(from: 0);
      _connectorController.reset();
      _resultController.reset();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _connectorController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _handleLeftTap(String pairId) {
    if (_isLocked) return;

    HapticFeedback.selectionClick();
    setState(() {
      final hadMatch = _matches.containsKey(pairId);
      if (_selectedLeftPairId == pairId && !hadMatch) {
        _selectedLeftPairId = null;
        return;
      }

      if (hadMatch) {
        _matches.remove(pairId);
      }
      _selectedLeftPairId = pairId;
    });
  }

  void _handleRightTap(String pairId) {
    final selectedLeft = _selectedLeftPairId;
    if (_isLocked || selectedLeft == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _matches.removeWhere(
        (leftPairId, rightPairId) =>
            rightPairId == pairId && leftPairId != selectedLeft,
      );
      _matches[selectedLeft] = pairId;
      _selectedLeftPairId = null;
    });
    _connectorController.forward(from: 0);
  }

  bool get _isLocked =>
      _phase == _MatchFlowPhase.submitting ||
      _phase == _MatchFlowPhase.analysis;

  bool get _hasSubmitted =>
      _phase == _MatchFlowPhase.submitting ||
      _phase == _MatchFlowPhase.analysis;

  int get _correctPairCount {
    var count = 0;
    for (final pair in widget.question.pairs) {
      if (_matches[pair.id] == pair.id) count++;
    }
    return count;
  }

  int get _availableCoins {
    return widget.coinBalanceOverride ??
        ref.watch(walletControllerProvider).valueOrNull?.coins ??
        0;
  }

  void _submitIfReady() {
    if (_matches.length != widget.question.pairs.length || _isLocked) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _MatchFlowPhase.analysis;
      _selectedLeftPairId = null;
    });
    _resultController.forward(from: 0);
  }

  void _showHint() {
    if (_isLocked || _isHintVisible) return;
    setState(() => _isHintVisible = true);
  }

  void _autoMatchOne() {
    if (_isLocked || _isAutoMatchUsed) return;
    MatchPair? pair;
    for (final candidate in widget.question.pairs) {
      if (_matches[candidate.id] != candidate.id) {
        pair = candidate;
        break;
      }
    }
    if (pair == null) return;
    final selectedPair = pair;

    setState(() {
      _isAutoMatchUsed = true;
      _matches.removeWhere(
        (leftPairId, rightPairId) =>
            rightPairId == selectedPair.id && leftPairId != selectedPair.id,
      );
      _matches[selectedPair.id] = selectedPair.id;
      _selectedLeftPairId = null;
    });
    _connectorController.forward(from: 0);
  }

  void _shuffleAnswers() {
    if (_isLocked || _isShuffleUsed) return;
    setState(() {
      _isShuffleUsed = true;
      _shuffledRight.shuffle(
        Random(widget.question.id.hashCode + _matches.length + 17),
      );
    });
  }

  GlobalKey _anchorKey(Map<String, GlobalKey> keys, String pairId) {
    return keys.putIfAbsent(pairId, GlobalKey.new);
  }

  void _scheduleMeasurements() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final boardBox = _boardKey.currentContext?.findRenderObject();
      if (boardBox is! RenderBox || !boardBox.hasSize) return;

      Map<String, Offset> measureAnchors(Map<String, GlobalKey> keys) {
        final anchors = <String, Offset>{};
        for (final entry in keys.entries) {
          final anchorBox = entry.value.currentContext?.findRenderObject();
          if (anchorBox is! RenderBox || !anchorBox.hasSize) continue;
          anchors[entry.key] = boardBox.globalToLocal(
            anchorBox.localToGlobal(anchorBox.size.center(Offset.zero)),
          );
        }
        return anchors;
      }

      final nextLeftAnchors = measureAnchors(_leftAnchorKeys);
      final nextRightAnchors = measureAnchors(_rightAnchorKeys);
      if (mapEquals(nextLeftAnchors, _leftAnchors) &&
          mapEquals(nextRightAnchors, _rightAnchors)) {
        return;
      }
      setState(() {
        _leftAnchors = nextLeftAnchors;
        _rightAnchors = nextRightAnchors;
      });
    });
  }

  void _continueAfterAnalysis() {
    if (_phase != _MatchFlowPhase.analysis) return;
    setState(() => _phase = _MatchFlowPhase.submitting);
    widget.onSubmit(
      MatchTheFollowingAnswer(
        questionId: widget.question.id,
        matchedPairIds: Map.of(_matches),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final streak =
        ref.watch(streakControllerProvider).valueOrNull?.currentStreak ?? 0;
    final matchedCount = _matches.length;
    final totalPairs = widget.question.pairs.length;
    final allMatched = matchedCount == totalPairs;
    final isAnalysis = _phase == _MatchFlowPhase.analysis;
    final boardHeight = totalPairs * (_cardHeight + _rowGap);

    return ColoredBox(
      key: const Key('match_it_view'),
      color: colors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MatchItHeader(
                title: _subjectTitle(widget.question.topicId),
                currentIndex: widget.currentIndex,
                totalQuestions: widget.totalQuestions,
                streak: streak,
                coins: _availableCoins,
                onExit: widget.onExit ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: AppSpacing.md),
              _ProgressHud(matchedCount: matchedCount, totalPairs: totalPairs),
              const SizedBox(height: AppSpacing.md),
              GamePowerUpBar(
                isDense: true,
                coinBalanceOverride: widget.coinBalanceOverride,
                isDisabled: _isLocked,
                actions: [
                  GamePowerUpAction(
                    id: 'match-hint',
                    label: 'Hint',
                    description: 'Show a pairing strategy for this board.',
                    coinCost: 10,
                    icon: Icons.lightbulb_outline,
                    isUsed: _isHintVisible,
                    onUse: _showHint,
                  ),
                  GamePowerUpAction(
                    id: 'auto-match',
                    label: 'Auto 1',
                    description: 'Correctly match one remaining pair.',
                    coinCost: 30,
                    icon: Icons.auto_awesome_rounded,
                    isUsed: _isAutoMatchUsed,
                    onUse: _autoMatchOne,
                  ),
                  GamePowerUpAction(
                    id: 'shuffle',
                    label: 'Shuffle',
                    description: 'Shuffle the answer side.',
                    coinCost: 15,
                    icon: Icons.shuffle_rounded,
                    isUsed: _isShuffleUsed,
                    onUse: _shuffleAnswers,
                  ),
                ],
              ),
              if (_isHintVisible) ...[
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  variant: AppCardVariant.tinted,
                  tintColor: colors.primary,
                  borderRadius: AppDimensions.radiusLg,
                  child: Text(
                    'Start with the clearest concept, then remove any pair you are unsure about before final submit.',
                    style: context.appTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: boardHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _scheduleMeasurements();
                    return Stack(
                      key: _boardKey,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            key: const Key('match_connection_layer'),
                            child: CustomPaint(
                              painter: _MatchConnectionPainter(
                                connectorAnimation: _connectorController,
                                resultAnimation: _resultController,
                                leftPairs: widget.question.pairs,
                                rightPairs: _shuffledRight,
                                matches: _matches,
                                leftAnchors: _leftAnchors,
                                rightAnchors: _rightAnchors,
                                hasSubmitted: _hasSubmitted,
                                selectedLeftPairId: _selectedLeftPairId,
                                cardHeight: _cardHeight,
                                rowGap: _rowGap,
                                connectorGap: _connectorGap,
                                successColor: colors.success,
                                errorColor: colors.error,
                                selectedColor: colors.secondary,
                                neutralColor: colors.borderStrong,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (final indexed
                                      in widget.question.pairs.indexed)
                                    _EntryMotion(
                                      controller: _entryController,
                                      index: indexed.$1,
                                      side: _MatchCardSide.left,
                                      child: _MatchConceptCard(
                                        key: Key('match-left-${indexed.$2.id}'),
                                        anchorKey: _anchorKey(
                                          _leftAnchorKeys,
                                          indexed.$2.id,
                                        ),
                                        anchorSemanticKey: Key(
                                          'match-left-anchor-${indexed.$2.id}',
                                        ),
                                        label: indexed.$2.left,
                                        side: _MatchCardSide.left,
                                        state: _leftState(indexed.$2.id),
                                        correctionText: isAnalysis
                                            ? _leftCorrection(indexed.$2.id)
                                            : null,
                                        onTap: _isLocked
                                            ? null
                                            : () =>
                                                  _handleLeftTap(indexed.$2.id),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: _connectorGap),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final indexed in _shuffledRight.indexed)
                                    AnimatedSwitcher(
                                      duration: AppMotion.duration(
                                        context,
                                        AppMotion.slow,
                                      ),
                                      switchInCurve: AppMotion.easeOut,
                                      switchOutCurve: AppMotion.easeIn,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0.12, 0),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          ),
                                      child: _EntryMotion(
                                        key: ValueKey(
                                          'match-right-entry-${indexed.$2.id}',
                                        ),
                                        controller: _entryController,
                                        index: indexed.$1,
                                        side: _MatchCardSide.right,
                                        child: _MatchConceptCard(
                                          key: Key(
                                            'match-right-${indexed.$2.id}',
                                          ),
                                          anchorKey: _anchorKey(
                                            _rightAnchorKeys,
                                            indexed.$2.id,
                                          ),
                                          anchorSemanticKey: Key(
                                            'match-right-anchor-${indexed.$2.id}',
                                          ),
                                          label: indexed.$2.right,
                                          side: _MatchCardSide.right,
                                          state: _rightState(indexed.$2.id),
                                          onTap: _isLocked
                                              ? null
                                              : () => _handleRightTap(
                                                  indexed.$2.id,
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isAnalysis) ...[
                _MatchAnalysisSummary(
                  question: widget.question,
                  matches: _matches,
                  correctPairCount: _correctPairCount,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AnimatedScale(
                duration: AppMotion.duration(context, AppMotion.normal),
                curve: AppMotion.easeOut,
                scale: isAnalysis || allMatched ? 1 : 0.98,
                child: AnimatedOpacity(
                  duration: AppMotion.duration(context, AppMotion.normal),
                  opacity: isAnalysis || allMatched ? 1 : 0.58,
                  child: AppButton(
                    label: isAnalysis ? 'Next' : 'Submit',
                    isLoading: _phase == _MatchFlowPhase.submitting,
                    onPressed: isAnalysis
                        ? _continueAfterAnalysis
                        : allMatched
                        ? _submitIfReady
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _MatchCardState _leftState(String pairId) {
    if (_matches.containsKey(pairId)) {
      if (_hasSubmitted) {
        return _matches[pairId] == pairId
            ? _MatchCardState.correct
            : _MatchCardState.wrong;
      }
      return _MatchCardState.matched;
    }
    if (_selectedLeftPairId == pairId) return _MatchCardState.selected;
    return _MatchCardState.neutral;
  }

  _MatchCardState _rightState(String pairId) {
    final matchedLeftPairId = _leftPairIdForRight(pairId);
    if (matchedLeftPairId != null) {
      if (_hasSubmitted) {
        return matchedLeftPairId == pairId
            ? _MatchCardState.correct
            : _MatchCardState.wrong;
      }
      return _MatchCardState.matched;
    }
    return _MatchCardState.neutral;
  }

  String? _leftPairIdForRight(String rightPairId) {
    for (final entry in _matches.entries) {
      if (entry.value == rightPairId) return entry.key;
    }
    return null;
  }

  String? _leftCorrection(String leftPairId) {
    if (_matches[leftPairId] == leftPairId) return null;
    for (final pair in widget.question.pairs) {
      if (pair.id == leftPairId) return 'Correct: ${pair.right}';
    }
    return null;
  }

  String _subjectTitle(String topicId) {
    final pathId = topicId.split('-chapter-').first;
    final words = pathId.split('-').where((word) => word.isNotEmpty);
    if (words.isEmpty) return 'Match It';
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

enum _MatchFlowPhase { playing, analysis, submitting }

class _MatchItHeader extends StatelessWidget {
  final String title;
  final int currentIndex;
  final int totalQuestions;
  final int streak;
  final int coins;
  final VoidCallback onExit;

  const _MatchItHeader({
    required this.title,
    required this.currentIndex,
    required this.totalQuestions,
    required this.streak,
    required this.coins,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Row(
      children: [
        AppPressable(
          onTap: onExit,
          borderRadius: AppDimensions.radiusCircular,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: AppElevation.shadows(colors, 2),
            ),
            child: Icon(Icons.close, color: colors.primary, size: 30),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: colors.warning,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.headingMedium.copyWith(
                        color: colors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.workspace_premium,
                    color: colors.warning,
                    size: 26,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '✦ Match It ✦',
                style: context.appTextStyles.bodyMedium.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${currentIndex + 1}/$totalQuestions',
          style: context.appTextStyles.labelLarge.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusPill(
          icon: Icons.local_fire_department,
          iconColor: AppColors.streakFire,
          value: streak,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusPill(
          icon: Icons.bolt,
          iconColor: AppColors.coinGold,
          value: coins,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;

  const _StatusPill({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      height: 48,
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppDimensions.radiusLg,
        border: Border.all(color: colors.borderStrong),
        boxShadow: AppElevation.shadows(colors, 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: AppSpacing.xs),
          AnimatedCountText(
            value: value,
            style: context.appTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ProgressHud extends StatelessWidget {
  final int matchedCount;
  final int totalPairs;

  const _ProgressHud({required this.matchedCount, required this.totalPairs});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final progress = totalPairs == 0 ? 0.0 : matchedCount / totalPairs;

    return AppCard(
      borderRadius: AppDimensions.radiusLg,
      elevationLevel: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Match each concept',
                  style: context.appTextStyles.titleLarge.copyWith(
                    color: colors.primaryDark,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$matchedCount of $totalPairs',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: ' matched'),
                  ],
                ),
                style: context.appTextStyles.titleMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppProgressBar(
                value: progress,
                height: 10,
                accentColor: colors.primary,
                trackColor: colors.primary.withValues(alpha: 0.10),
                semanticLabel: 'Match progress',
              ),
              Positioned(
                left: max(0, progress * 100).clamp(0, 100) == 0 ? 0 : null,
                right: progress >= 1 ? 0 : null,
                top: -7,
                child: FractionalTranslation(
                  translation: Offset(progress >= 1 ? 0 : progress * 19, 0),
                  child: Icon(Icons.star, color: colors.violet, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchAnalysisSummary extends StatelessWidget {
  final MatchTheFollowingQuestion question;
  final Map<String, String> matches;
  final int correctPairCount;

  const _MatchAnalysisSummary({
    required this.question,
    required this.matches,
    required this.correctPairCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final wrongPairs = question.pairs
        .where((pair) => matches[pair.id] != pair.id)
        .toList();
    final wrongCount = wrongPairs.length;

    return AppCard(
      key: const Key('match_analysis_summary'),
      variant: AppCardVariant.tinted,
      tintColor: wrongCount == 0 ? colors.success : colors.warning,
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MatchMetricTile(
                  label: 'Correct',
                  value: correctPairCount,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MatchMetricTile(
                  label: 'Wrong',
                  value: wrongCount,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MatchMetricTile(
                  label: 'Score',
                  value: _scorePercent,
                  suffix: '%',
                  color: colors.primary,
                ),
              ),
            ],
          ),
          if (wrongPairs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _CorrectionDisclosure(
              wrongPairs: wrongPairs,
              matches: matches,
              rightLabelFor: _rightLabelFor,
            ),
          ],
        ],
      ),
    );
  }

  int get _scorePercent {
    if (question.pairs.isEmpty) return 0;
    return (correctPairCount * 100 / question.pairs.length).round();
  }

  String _rightLabelFor(String? pairId) {
    if (pairId == null) return 'No answer selected';
    for (final pair in question.pairs) {
      if (pair.id == pairId) return pair.right;
    }
    return 'Unknown answer';
  }
}

class _CorrectionDisclosure extends StatefulWidget {
  final List<MatchPair> wrongPairs;
  final Map<String, String> matches;
  final String Function(String? pairId) rightLabelFor;

  const _CorrectionDisclosure({
    required this.wrongPairs,
    required this.matches,
    required this.rightLabelFor,
  });

  @override
  State<_CorrectionDisclosure> createState() => _CorrectionDisclosureState();
}

class _CorrectionDisclosureState extends State<_CorrectionDisclosure> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final wrongCount = widget.wrongPairs.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.52),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          AppPressable(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppDimensions.radiusMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '$wrongCount ${wrongCount == 1 ? 'answer' : 'answers'} need review',
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _isExpanded ? 'Hide' : 'View corrections',
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    turns: _isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.duration(context, AppMotion.normal),
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      0,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        for (final pair in widget.wrongPairs) ...[
                          _CorrectAnswerRow(
                            key: Key('match-correct-answer-${pair.id}'),
                            leftLabel: pair.left,
                            selectedRightLabel: widget.rightLabelFor(
                              widget.matches[pair.id],
                            ),
                            correctRightLabel: pair.right,
                          ),
                          if (pair != widget.wrongPairs.last)
                            const SizedBox(height: AppSpacing.xs),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MatchMetricTile extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final Color color;

  const _MatchMetricTile({
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value$suffix',
              style: context.appTextStyles.titleMedium.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectAnswerRow extends StatelessWidget {
  final String leftLabel;
  final String selectedRightLabel;
  final String correctRightLabel;

  const _CorrectAnswerRow({
    super.key,
    required this.leftLabel,
    required this.selectedRightLabel,
    required this.correctRightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.52),
        borderRadius: AppDimensions.radiusSm,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              leftLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your match: $selectedRightLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelSmall.copyWith(
                color: colors.error,
              ),
            ),
            Text(
              'Correct: $correctRightLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelSmall.copyWith(
                color: colors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MatchCardSide { left, right }

class _EntryMotion extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final _MatchCardSide side;
  final Widget child;

  const _EntryMotion({
    super.key,
    required this.controller,
    required this.index,
    required this.side,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.14).clamp(0.0, 0.72);
    final end = (start + 0.28).clamp(start + 0.01, 1.0);
    final animation = controller.drive(
      CurveTween(curve: Interval(start, end, curve: AppMotion.easeOut)),
    );
    final begin = side == _MatchCardSide.left
        ? const Offset(-0.18, 0)
        : const Offset(0.18, 0);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
    );
  }
}

enum _MatchCardState { neutral, selected, matched, correct, wrong }

class _MatchConceptCard extends StatelessWidget {
  final GlobalKey anchorKey;
  final Key anchorSemanticKey;
  final String label;
  final _MatchCardSide side;
  final _MatchCardState state;
  final String? correctionText;
  final VoidCallback? onTap;

  const _MatchConceptCard({
    super.key,
    required this.anchorKey,
    required this.anchorSemanticKey,
    required this.label,
    required this.side,
    required this.state,
    this.correctionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final indicator = _statusIndicator(colors);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: _MatchTheFollowingViewState._rowGap,
      ),
      child: Opacity(
        opacity: onTap == null ? 0.9 : 1,
        child: AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          scale: state == _MatchCardState.selected ? 1.02 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AppPressable(
                onTap: onTap,
                borderRadius: AppDimensions.radiusMd,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.normal),
                  curve: AppMotion.easeOut,
                  width: double.infinity,
                  height: _MatchTheFollowingViewState._cardHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: _background(colors),
                    borderRadius: AppDimensions.radiusMd,
                    border: Border.all(
                      color: _border(colors),
                      width: state == _MatchCardState.neutral ? 1 : 1.4,
                    ),
                    boxShadow: _shadows(colors),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (side == _MatchCardSide.right &&
                              indicator != null) ...[
                            indicator,
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: correctionText == null ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextStyles.bodyMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (side == _MatchCardSide.left &&
                              indicator != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            indicator,
                          ],
                        ],
                      ),
                      if (correctionText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          correctionText!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.labelSmall.copyWith(
                            color: colors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: side == _MatchCardSide.right ? -11 : null,
                right: side == _MatchCardSide.left ? -11 : null,
                child: Center(child: _node(context, colors)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _statusIndicator(AppThemeColors colors) {
    if (state != _MatchCardState.correct && state != _MatchCardState.wrong) {
      return null;
    }

    final isCorrect = state == _MatchCardState.correct;
    final color = isCorrect ? colors.success : colors.error;
    return Icon(
      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: color,
      size: 20,
    );
  }

  Widget _node(BuildContext context, AppThemeColors colors) {
    final color = _border(colors);
    final isSelected = state == _MatchCardState.selected;
    final isResolved =
        state == _MatchCardState.correct || state == _MatchCardState.wrong;

    return KeyedSubtree(
      key: anchorSemanticKey,
      child: SizedBox(
        key: anchorKey,
        width: 22,
        height: 22,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          decoration: BoxDecoration(
            color: colors.background,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isResolved ? 2.8 : 2.4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : AppElevation.shadows(colors, 1),
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }

  Color _background(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct => colors.success.withValues(alpha: 0.045),
      _MatchCardState.wrong => colors.error.withValues(alpha: 0.04),
      _MatchCardState.selected => colors.primary.withValues(alpha: 0.08),
      _MatchCardState.matched => colors.secondary.withValues(alpha: 0.055),
      _MatchCardState.neutral => colors.surface,
    };
  }

  Color _border(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct => colors.success,
      _MatchCardState.wrong => colors.error,
      _MatchCardState.selected => colors.primary,
      _MatchCardState.matched => colors.secondary,
      _MatchCardState.neutral => colors.borderStrong,
    };
  }

  List<BoxShadow> _shadows(AppThemeColors colors) {
    final shadows = List<BoxShadow>.of(AppElevation.shadows(colors, 1));
    if (state == _MatchCardState.selected) {
      shadows.add(
        BoxShadow(
          color: colors.primary.withValues(alpha: 0.16),
          blurRadius: 12,
        ),
      );
    }
    return shadows;
  }
}

class _MatchConnectionPainter extends CustomPainter {
  final Animation<double> connectorAnimation;
  final Animation<double> resultAnimation;
  final List<MatchPair> leftPairs;
  final List<MatchPair> rightPairs;
  final Map<String, String> matches;
  final Map<String, Offset> leftAnchors;
  final Map<String, Offset> rightAnchors;
  final bool hasSubmitted;
  final String? selectedLeftPairId;
  final double cardHeight;
  final double rowGap;
  final double connectorGap;
  final Color successColor;
  final Color errorColor;
  final Color selectedColor;
  final Color neutralColor;

  _MatchConnectionPainter({
    required this.connectorAnimation,
    required this.resultAnimation,
    required this.leftPairs,
    required this.rightPairs,
    required this.matches,
    required this.leftAnchors,
    required this.rightAnchors,
    required this.hasSubmitted,
    required this.selectedLeftPairId,
    required this.cardHeight,
    required this.rowGap,
    required this.connectorGap,
    required this.successColor,
    required this.errorColor,
    required this.selectedColor,
    required this.neutralColor,
  }) : super(repaint: Listenable.merge([connectorAnimation, resultAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final entries = matches.entries.toList(growable: false);
    for (final indexedEntry in entries.indexed) {
      final index = indexedEntry.$1;
      final entry = indexedEntry.$2;
      final resultColor = entry.key == entry.value ? successColor : errorColor;
      final evaluationProgress = hasSubmitted
          ? ((resultAnimation.value * entries.length) - index)
                .clamp(0.0, 1.0)
                .toDouble()
          : 0.0;
      final color = hasSubmitted
          ? Color.lerp(
              neutralColor,
              resultColor,
              Curves.easeOut.transform(evaluationProgress),
            )!
          : selectedColor;
      final progress = hasSubmitted
          ? evaluationProgress
          : connectorAnimation.value;
      _drawConnection(canvas, size, entry.key, entry.value, color, progress);
    }

    if (!hasSubmitted && selectedLeftPairId != null) {
      final leftIndex = leftPairs.indexWhere(
        (pair) => pair.id == selectedLeftPairId,
      );
      if (leftIndex >= 0) {
        final start =
            leftAnchors[selectedLeftPairId] ??
            Offset(_leftX(size), _rowCenterY(leftIndex));
        final end = Offset(size.width / 2, start.dy);
        _drawCurve(
          canvas,
          start,
          end,
          selectedColor.withValues(alpha: 0.38),
          2,
          1,
        );
      }
    }
  }

  void _drawConnection(
    Canvas canvas,
    Size size,
    String leftPairId,
    String rightPairId,
    Color color,
    double progress,
  ) {
    final leftIndex = leftPairs.indexWhere((pair) => pair.id == leftPairId);
    final rightIndex = rightPairs.indexWhere((pair) => pair.id == rightPairId);
    if (leftIndex < 0 || rightIndex < 0) return;

    final leftAnchor =
        leftAnchors[leftPairId] ?? Offset(_leftX(size), _rowCenterY(leftIndex));
    final rightAnchor =
        rightAnchors[rightPairId] ??
        Offset(_rightX(size), _rowCenterY(rightIndex));
    _drawCurve(canvas, leftAnchor, rightAnchor, color, 2.6, progress);
  }

  void _drawCurve(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double width,
    double progress,
  ) {
    if (progress <= 0) return;
    if ((end - start).distance < 0.5) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final controlOffset = max(24.0, (end.dx - start.dx).abs() * 0.45);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + controlOffset,
        start.dy,
        end.dx - controlOffset,
        end.dy,
        end.dx,
        end.dy,
      );
    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    if (metric.length <= 0) return;
    final visiblePath = metric.extractPath(
      0,
      metric.length * progress.clamp(0, 1),
    );
    canvas.drawPath(visiblePath, paint);
  }

  double _leftX(Size size) => (size.width - connectorGap) / 2;

  double _rightX(Size size) => (size.width + connectorGap) / 2;

  double _rowCenterY(int index) =>
      index * (cardHeight + rowGap) + cardHeight / 2;

  @override
  bool shouldRepaint(covariant _MatchConnectionPainter oldDelegate) {
    return oldDelegate.matches != matches ||
        oldDelegate.leftAnchors != leftAnchors ||
        oldDelegate.rightAnchors != rightAnchors ||
        oldDelegate.hasSubmitted != hasSubmitted ||
        oldDelegate.selectedLeftPairId != selectedLeftPairId ||
        oldDelegate.neutralColor != neutralColor;
  }
}
