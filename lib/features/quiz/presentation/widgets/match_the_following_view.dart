import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const MatchTheFollowingView({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onExit,
    this.coinBalanceOverride,
  });

  @override
  ConsumerState<MatchTheFollowingView> createState() =>
      _MatchTheFollowingViewState();
}

class _MatchTheFollowingViewState extends ConsumerState<MatchTheFollowingView> {
  static const double _cardHeight = 64;
  static const double _rowGap = 12;
  static const double _connectorGap = 64;

  late List<MatchPair> _shuffledRight;

  final Map<String, String> _matches = {};

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
                streak: streak,
                coins: _availableCoins,
                onExit: widget.onExit ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: AppSpacing.md),
              _ProgressHud(matchedCount: matchedCount, totalPairs: totalPairs),
              const SizedBox(height: AppSpacing.lg),
              GamePowerUpBar(
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
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: boardHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MatchConnectionPainter(
                              leftPairs: widget.question.pairs,
                              rightPairs: _shuffledRight,
                              matches: _matches,
                              hasSubmitted: _hasSubmitted,
                              selectedLeftPairId: _selectedLeftPairId,
                              cardHeight: _cardHeight,
                              rowGap: _rowGap,
                              connectorGap: _connectorGap,
                              successColor: colors.success,
                              errorColor: colors.error,
                              selectedColor: colors.primary,
                              neutralColor: colors.borderStrong,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (final pair in widget.question.pairs)
                                    _MatchConceptCard(
                                      key: Key('match-left-${pair.id}'),
                                      label: pair.left,
                                      side: _MatchCardSide.left,
                                      state: _leftState(pair.id),
                                      onTap: _isLocked
                                          ? null
                                          : () => _handleLeftTap(pair.id),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: _connectorGap),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final pair in _shuffledRight)
                                    _MatchConceptCard(
                                      key: Key('match-right-${pair.id}'),
                                      label: pair.right,
                                      side: _MatchCardSide.right,
                                      state: _rightState(pair.id),
                                      onTap: _isLocked
                                          ? null
                                          : () => _handleRightTap(pair.id),
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
              AppButton(
                label: isAnalysis ? 'Continue' : 'Submit',
                isLoading: _phase == _MatchFlowPhase.submitting,
                onPressed: isAnalysis
                    ? _continueAfterAnalysis
                    : allMatched
                    ? _submitIfReady
                    : null,
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
  final int streak;
  final int coins;
  final VoidCallback onExit;

  const _MatchItHeader({
    required this.title,
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
            const SizedBox(height: AppSpacing.md),
            Text(
              'Correct answers',
              style: context.appTextStyles.titleMedium.copyWith(
                color: colors.primaryDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final pair in wrongPairs) ...[
              _CorrectAnswerRow(
                key: Key('match-correct-answer-${pair.id}'),
                leftLabel: pair.left,
                selectedRightLabel: _rightLabelFor(matches[pair.id]),
                correctRightLabel: pair.right,
              ),
              if (pair != wrongPairs.last)
                const SizedBox(height: AppSpacing.sm),
            ],
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
        color: color.withValues(alpha: 0.10),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: AppSpacing.paddingSm,
        child: Column(
          children: [
            Text(
              '$value$suffix',
              style: context.appTextStyles.titleLarge.copyWith(color: color),
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
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: AppSpacing.paddingSm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leftLabel, style: context.appTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Selected: $selectedRightLabel',
              style: context.appTextStyles.bodySmall.copyWith(
                color: colors.error,
              ),
            ),
            Text(
              'Correct: $correctRightLabel',
              style: context.appTextStyles.bodySmall.copyWith(
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

enum _MatchCardState { neutral, selected, matched, correct, wrong }

class _MatchConceptCard extends StatelessWidget {
  final String label;
  final _MatchCardSide side;
  final _MatchCardState state;
  final VoidCallback? onTap;

  const _MatchConceptCard({
    super.key,
    required this.label,
    required this.side,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final node = _node(colors);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: _MatchTheFollowingViewState._rowGap,
      ),
      child: Opacity(
        opacity: onTap == null ? 0.88 : 1,
        child: AppPressable(
          onTap: onTap,
          borderRadius: AppDimensions.radiusMd,
          child: SizedBox(
            height: _MatchTheFollowingViewState._cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
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
                      width: state == _MatchCardState.neutral ? 1 : 1.5,
                    ),
                    boxShadow: AppElevation.shadows(
                      colors,
                      state == _MatchCardState.neutral ? 1 : 0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.bodyLarge.copyWith(
                        color: _textColor(colors),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: side == _MatchCardSide.right ? -10 : null,
                  right: side == _MatchCardSide.left ? -10 : null,
                  child: node,
                ),
                if (state == _MatchCardState.correct ||
                    state == _MatchCardState.wrong)
                  Positioned(
                    right: side == _MatchCardSide.left ? 28 : null,
                    left: side == _MatchCardSide.right ? 28 : null,
                    child: Icon(
                      state == _MatchCardState.correct
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: state == _MatchCardState.correct
                          ? colors.success
                          : colors.error,
                      size: 26,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _node(AppThemeColors colors) {
    final color = _border(colors);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: AppElevation.shadows(colors, 1),
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Color _background(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct => colors.success.withValues(alpha: 0.10),
      _MatchCardState.wrong => colors.error.withValues(alpha: 0.08),
      _MatchCardState.selected => colors.primary.withValues(alpha: 0.08),
      _MatchCardState.matched => colors.primary.withValues(alpha: 0.06),
      _MatchCardState.neutral => colors.surface,
    };
  }

  Color _border(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct => colors.success,
      _MatchCardState.wrong => colors.error,
      _MatchCardState.selected => colors.primary,
      _MatchCardState.matched => colors.primary,
      _MatchCardState.neutral => colors.borderStrong,
    };
  }

  Color _textColor(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct => colors.success,
      _MatchCardState.wrong => colors.error,
      _ => colors.textPrimary,
    };
  }
}

class _MatchConnectionPainter extends CustomPainter {
  final List<MatchPair> leftPairs;
  final List<MatchPair> rightPairs;
  final Map<String, String> matches;
  final bool hasSubmitted;
  final String? selectedLeftPairId;
  final double cardHeight;
  final double rowGap;
  final double connectorGap;
  final Color successColor;
  final Color errorColor;
  final Color selectedColor;
  final Color neutralColor;

  const _MatchConnectionPainter({
    required this.leftPairs,
    required this.rightPairs,
    required this.matches,
    required this.hasSubmitted,
    required this.selectedLeftPairId,
    required this.cardHeight,
    required this.rowGap,
    required this.connectorGap,
    required this.successColor,
    required this.errorColor,
    required this.selectedColor,
    required this.neutralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in matches.entries) {
      final color = hasSubmitted
          ? entry.key == entry.value
                ? successColor
                : errorColor
          : selectedColor;
      _drawConnection(canvas, size, entry.key, entry.value, color);
    }

    if (!hasSubmitted && selectedLeftPairId != null) {
      final leftIndex = leftPairs.indexWhere(
        (pair) => pair.id == selectedLeftPairId,
      );
      if (leftIndex >= 0) {
        final start = Offset(_leftX(size), _rowCenterY(leftIndex));
        final end = Offset(size.width / 2, _rowCenterY(leftIndex));
        _drawCurve(
          canvas,
          start,
          end,
          selectedColor.withValues(alpha: 0.45),
          2,
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
  ) {
    final leftIndex = leftPairs.indexWhere((pair) => pair.id == leftPairId);
    final rightIndex = rightPairs.indexWhere((pair) => pair.id == rightPairId);
    if (leftIndex < 0 || rightIndex < 0) return;

    _drawCurve(
      canvas,
      Offset(_leftX(size), _rowCenterY(leftIndex)),
      Offset(_rightX(size), _rowCenterY(rightIndex)),
      color,
      3,
    );
  }

  void _drawCurve(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx + 38, start.dy, end.dx - 38, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  double _leftX(Size size) => (size.width - connectorGap) / 2;

  double _rightX(Size size) => (size.width + connectorGap) / 2;

  double _rowCenterY(int index) =>
      index * (cardHeight + rowGap) + cardHeight / 2;

  @override
  bool shouldRepaint(covariant _MatchConnectionPainter oldDelegate) {
    return oldDelegate.matches != matches ||
        oldDelegate.hasSubmitted != hasSubmitted ||
        oldDelegate.selectedLeftPairId != selectedLeftPairId ||
        oldDelegate.neutralColor != neutralColor;
  }
}
