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
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class MatchTheFollowingView extends ConsumerStatefulWidget {
  final MatchTheFollowingQuestion question;
  final void Function(Answer answer) onSubmit;
  final VoidCallback? onExit;
  final int? coinBalanceOverride;
  final Future<bool> Function(int amount, String reason)? spendCoinsOverride;

  const MatchTheFollowingView({
    super.key,
    required this.question,
    required this.onSubmit,
    this.onExit,
    this.coinBalanceOverride,
    this.spendCoinsOverride,
  });

  @override
  ConsumerState<MatchTheFollowingView> createState() =>
      _MatchTheFollowingViewState();
}

class _MatchTheFollowingViewState extends ConsumerState<MatchTheFollowingView>
    with SingleTickerProviderStateMixin {
  static const int _removeOneCost = 10;
  static const int _revealMatchCost = 20;
  static const double _cardHeight = 64;
  static const double _rowGap = 12;
  static const double _connectorGap = 64;

  late final List<MatchPair> _shuffledRight;
  late final AnimationController _shakeController;

  final Map<String, String> _matches = {};
  final Set<String> _assistedPairs = {};
  final Map<String, Set<String>> _eliminatedRightIdsByLeft = {};

  String? _selectedLeftPairId;
  _MismatchAttempt? _mismatchAttempt;
  String? _hintText;
  int _hintsRemaining = 1;

  @override
  void initState() {
    super.initState();
    _shuffledRight = List.of(widget.question.pairs);
    _shuffledRight.shuffle(Random(widget.question.id.hashCode));
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleLeftTap(String pairId) {
    if (_matches.containsKey(pairId)) return;
    setState(() {
      _mismatchAttempt = null;
      _selectedLeftPairId = _selectedLeftPairId == pairId ? null : pairId;
    });
  }

  void _handleRightTap(String pairId) {
    final selectedLeft = _selectedLeftPairId;
    if (selectedLeft == null ||
        _matches.containsValue(pairId) ||
        _isEliminated(selectedLeft, pairId)) {
      return;
    }

    if (selectedLeft == pairId) {
      HapticFeedback.selectionClick();
      setState(() {
        _matches[selectedLeft] = pairId;
        _selectedLeftPairId = null;
        _mismatchAttempt = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _mismatchAttempt = _MismatchAttempt(
        leftPairId: selectedLeft,
        rightPairId: pairId,
      );
      _selectedLeftPairId = null;
    });
    _shakeController.forward(from: 0);
    _openPowerUpSheet();
  }

  bool _isEliminated(String leftPairId, String rightPairId) {
    return _eliminatedRightIdsByLeft[leftPairId]?.contains(rightPairId) ??
        false;
  }

  Future<void> _useHint(VoidCallback refreshSheet) async {
    final pair = _selectedPair();
    if (pair == null) {
      _showMessage('Select a concept first.');
      return;
    }
    if (_hintsRemaining < 1) {
      _showMessage('No hints left.');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _hintsRemaining -= 1;
      _hintText =
          pair.hint ??
          'Focus on what "${pair.left}" means, then look for the closest definition.';
    });
    refreshSheet();
  }

  Future<void> _removeOne(VoidCallback refreshSheet) async {
    final selectedLeft = _selectedLeftPairId;
    if (selectedLeft == null) {
      _showMessage('Select a concept first.');
      return;
    }

    final removable = _shuffledRight.where((pair) {
      return pair.id != selectedLeft &&
          !_matches.containsValue(pair.id) &&
          !_isEliminated(selectedLeft, pair.id);
    }).toList();
    if (removable.isEmpty) {
      _showMessage('No incorrect options left to remove.');
      return;
    }

    final confirmed = await _confirmSpend(
      amount: _removeOneCost,
      message: 'Use 10 coins to remove one incorrect option?',
      actionLabel: 'Use 10 Coins',
    );
    if (!confirmed || !mounted) return;

    final spent = await _spendCoins(_removeOneCost, 'Match It - Remove One');
    if (!mounted) return;
    if (!spent) {
      _showMessage('Not enough coins');
      return;
    }

    removable.sort((a, b) => a.id.compareTo(b.id));
    setState(() {
      _eliminatedRightIdsByLeft
          .putIfAbsent(selectedLeft, () => <String>{})
          .add(removable.first.id);
      _mismatchAttempt = null;
    });
    refreshSheet();
  }

  Future<void> _revealMatch(VoidCallback refreshSheet) async {
    final pair = _selectedPair();
    if (pair == null) {
      _showMessage('Select a concept first.');
      return;
    }
    if (_matches.containsKey(pair.id)) return;

    final confirmed = await _confirmSpend(
      amount: _revealMatchCost,
      message: 'Use 20 coins to reveal the correct match?',
      actionLabel: 'Use 20 Coins',
    );
    if (!confirmed || !mounted) return;

    final spent = await _spendCoins(
      _revealMatchCost,
      'Match It - Reveal Match',
    );
    if (!mounted) return;
    if (!spent) {
      _showMessage('Not enough coins');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _matches[pair.id] = pair.id;
      _assistedPairs.add(pair.id);
      _selectedLeftPairId = null;
      _mismatchAttempt = null;
    });
    refreshSheet();
  }

  Future<bool> _spendCoins(int amount, String reason) async {
    final override = widget.spendCoinsOverride;
    if (override != null) {
      return override(amount, reason);
    }

    return ref
        .read(walletControllerProvider.notifier)
        .debit(currency: CurrencyType.coins, amount: amount, reason: reason);
  }

  Future<bool> _confirmSpend({
    required int amount,
    required String message,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm power-up'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _keepTrying(BuildContext sheetContext) {
    HapticFeedback.selectionClick();
    setState(() => _mismatchAttempt = null);
    Navigator.of(sheetContext).pop();
  }

  void _openPowerUpSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _PowerUpBottomSheet(
              coins: _availableCoins,
              hintsRemaining: _hintsRemaining,
              hintText: _hintText,
              onHint: () => _useHint(() => setSheetState(() {})),
              onRemoveOne: () => _removeOne(() => setSheetState(() {})),
              onRevealMatch: () => _revealMatch(() => setSheetState(() {})),
              onKeepTrying: () => _keepTrying(sheetContext),
            );
          },
        );
      },
    );
  }

  MatchPair? _selectedPair() {
    final selectedLeft = _selectedLeftPairId;
    if (selectedLeft == null) return null;
    for (final pair in widget.question.pairs) {
      if (pair.id == selectedLeft) return pair;
    }
    return null;
  }

  int get _availableCoins {
    return widget.coinBalanceOverride ??
        ref.watch(walletControllerProvider).valueOrNull?.coins ??
        0;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitIfReady() {
    if (_matches.length != widget.question.pairs.length) return;
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
              _PowerUpStrip(
                hintsRemaining: _hintsRemaining,
                onHint: _openPowerUpSheet,
                onRemoveOne: _openPowerUpSheet,
                onRevealMatch: _openPowerUpSheet,
              ),
              if (_mismatchAttempt != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final dx = sin(_shakeController.value * pi * 4) * 5;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: const _MismatchFeedbackCard(),
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
                              mismatchAttempt: _mismatchAttempt,
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
                                      onTap: () => _handleLeftTap(pair.id),
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
                                      onTap: () => _handleRightTap(pair.id),
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
              AppButton(
                label: 'Submit',
                onPressed: allMatched ? _submitIfReady : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _MatchCardState _leftState(String pairId) {
    if (_mismatchAttempt?.leftPairId == pairId) return _MatchCardState.wrong;
    if (_matches.containsKey(pairId)) {
      return _assistedPairs.contains(pairId)
          ? _MatchCardState.assisted
          : _MatchCardState.correct;
    }
    if (_selectedLeftPairId == pairId) return _MatchCardState.selected;
    return _MatchCardState.neutral;
  }

  _MatchCardState _rightState(String pairId) {
    final selectedLeft = _selectedLeftPairId;
    if (_mismatchAttempt?.rightPairId == pairId) return _MatchCardState.wrong;
    if (_matches.containsValue(pairId)) {
      return _assistedPairs.contains(pairId)
          ? _MatchCardState.assisted
          : _MatchCardState.correct;
    }
    if (selectedLeft != null && _isEliminated(selectedLeft, pairId)) {
      return _MatchCardState.eliminated;
    }
    return _MatchCardState.neutral;
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

class _PowerUpStrip extends StatelessWidget {
  final int hintsRemaining;
  final VoidCallback onHint;
  final VoidCallback onRemoveOne;
  final VoidCallback onRevealMatch;

  const _PowerUpStrip({
    required this.hintsRemaining,
    required this.onHint,
    required this.onRemoveOne,
    required this.onRevealMatch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppDimensions.radiusLg,
            border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _PowerUpMiniCard(
                  icon: Icons.lightbulb,
                  iconColor: colors.warning,
                  title: 'Hint',
                  subtitle: '$hintsRemaining Free',
                  tint: colors.violet,
                  onTap: onHint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PowerUpMiniCard(
                  icon: Icons.remove,
                  iconColor: colors.warning,
                  title: 'Remove One',
                  subtitle: '10 Coins',
                  tint: colors.warning,
                  onTap: onRemoveOne,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PowerUpMiniCard(
                  icon: Icons.visibility,
                  iconColor: colors.info,
                  title: 'Reveal Match',
                  subtitle: '20 Coins',
                  tint: colors.info,
                  onTap: onRevealMatch,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: -15,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppDimensions.radiusCircular,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                '✦ POWER-UPS ✦',
                style: context.appTextStyles.labelLarge.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerUpMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  const _PowerUpMiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: AppSpacing.paddingSm,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tint.withValues(alpha: 0.12), colors.surface],
          ),
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: tint.withValues(alpha: 0.16), blurRadius: 8),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.labelSmall.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MismatchFeedbackCard extends StatelessWidget {
  const _MismatchFeedbackCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      key: const Key('match_mismatch_banner'),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: AppDimensions.radiusMd,
        border: Border.all(color: colors.error.withValues(alpha: 0.62)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.priority_high,
              color: colors.textInverse,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oops! Mismatch!',
                  style: context.appTextStyles.titleMedium.copyWith(
                    color: colors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "That pair doesn't match. Try again or use a lifeline.",
                  style: context.appTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.sentiment_very_dissatisfied, color: colors.error),
        ],
      ),
    );
  }
}

enum _MatchCardSide { left, right }

enum _MatchCardState { neutral, selected, correct, wrong, eliminated, assisted }

class _MatchConceptCard extends StatelessWidget {
  final String label;
  final _MatchCardSide side;
  final _MatchCardState state;
  final VoidCallback onTap;

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
    final isDisabled =
        state == _MatchCardState.correct ||
        state == _MatchCardState.assisted ||
        state == _MatchCardState.eliminated;
    final node = _node(colors);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: _MatchTheFollowingViewState._rowGap,
      ),
      child: Opacity(
        opacity: state == _MatchCardState.eliminated ? 0.44 : 1,
        child: AppPressable(
          onTap: isDisabled ? null : onTap,
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
                    state == _MatchCardState.assisted)
                  Positioned(
                    right: side == _MatchCardSide.left ? 28 : null,
                    left: side == _MatchCardSide.right ? 28 : null,
                    child: Icon(
                      state == _MatchCardState.assisted
                          ? Icons.auto_awesome
                          : Icons.check_circle,
                      color: colors.success,
                      size: 26,
                    ),
                  ),
                if (state == _MatchCardState.eliminated)
                  Icon(Icons.remove_circle, color: colors.warning, size: 28),
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
      _MatchCardState.assisted => colors.success.withValues(alpha: 0.08),
      _MatchCardState.wrong => colors.error.withValues(alpha: 0.08),
      _MatchCardState.selected => colors.primary.withValues(alpha: 0.08),
      _MatchCardState.eliminated => colors.warning.withValues(alpha: 0.08),
      _MatchCardState.neutral => colors.surface,
    };
  }

  Color _border(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct || _MatchCardState.assisted => colors.success,
      _MatchCardState.wrong => colors.error,
      _MatchCardState.selected => colors.primary,
      _MatchCardState.eliminated => colors.warning,
      _MatchCardState.neutral => colors.borderStrong,
    };
  }

  Color _textColor(AppThemeColors colors) {
    return switch (state) {
      _MatchCardState.correct || _MatchCardState.assisted => colors.success,
      _MatchCardState.wrong => colors.error,
      _ => colors.textPrimary,
    };
  }
}

class _PowerUpBottomSheet extends StatelessWidget {
  final int coins;
  final int hintsRemaining;
  final String? hintText;
  final VoidCallback onHint;
  final VoidCallback onRemoveOne;
  final VoidCallback onRevealMatch;
  final VoidCallback onKeepTrying;

  const _PowerUpBottomSheet({
    required this.coins,
    required this.hintsRemaining,
    required this.hintText,
    required this.onHint,
    required this.onRemoveOne,
    required this.onRevealMatch,
    required this.onKeepTrying,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Container(
      key: const Key('power_up_sheet'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.45),
                    borderRadius: AppDimensions.radiusCircular,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.violet],
                      ),
                      borderRadius: AppDimensions.radiusLg,
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: colors.primaryForeground,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose a Power-Up!',
                          style: context.appTextStyles.headingMedium.copyWith(
                            color: colors.primaryDark,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          "Get help or keep trying - you've got this!",
                          style: context.appTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),
                      borderRadius: AppDimensions.radiusLg,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: colors.warning, size: 24),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '$coins',
                              style: context.appTextStyles.titleMedium,
                            ),
                          ],
                        ),
                        Text(
                          'Available',
                          style: context.appTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PowerUpSheetOption(
                icon: Icons.lightbulb,
                tint: colors.violet,
                title: 'Hint',
                description: 'Get a clue about the selected concept.',
                trailing: '$hintsRemaining\nLEFT',
                onTap: onHint,
                child: hintText == null
                    ? null
                    : Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        padding: AppSpacing.paddingSm,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.10),
                          borderRadius: AppDimensions.radiusSm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: colors.violet,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                hintText!,
                                style: context.appTextStyles.bodyMedium
                                    .copyWith(color: colors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PowerUpSheetOption(
                icon: Icons.remove,
                tint: colors.warning,
                title: 'Remove One',
                description: 'Remove one incorrect option.',
                trailing: '10\nCOINS',
                onTap: onRemoveOne,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PowerUpSheetOption(
                icon: Icons.visibility,
                tint: colors.info,
                title: 'Reveal Match',
                description: 'Show the correct match for this concept.',
                trailing: '20\nCOINS',
                onTap: onRevealMatch,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onKeepTrying,
                child: Column(
                  children: [
                    Text(
                      '✦ Keep Trying ✦',
                      style: context.appTextStyles.titleMedium.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    Text(
                      'No coins needed',
                      style: context.appTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerUpSheetOption extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String description;
  final String trailing;
  final VoidCallback onTap;
  final Widget? child;

  const _PowerUpSheetOption({
    required this.icon,
    required this.tint,
    required this.title,
    required this.description,
    required this.trailing,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusMd,
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tint.withValues(alpha: 0.10), colors.surface],
          ),
          borderRadius: AppDimensions.radiusMd,
          border: Border.all(color: tint.withValues(alpha: 0.32)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 32),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: context.appTextStyles.bodyMedium),
                  ?child,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: Text(
                trailing,
                textAlign: TextAlign.center,
                style: context.appTextStyles.titleMedium.copyWith(color: tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MismatchAttempt {
  final String leftPairId;
  final String rightPairId;

  const _MismatchAttempt({required this.leftPairId, required this.rightPairId});
}

class _MatchConnectionPainter extends CustomPainter {
  final List<MatchPair> leftPairs;
  final List<MatchPair> rightPairs;
  final Map<String, String> matches;
  final _MismatchAttempt? mismatchAttempt;
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
    required this.mismatchAttempt,
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
      _drawConnection(canvas, size, entry.key, entry.value, successColor);
    }

    final wrong = mismatchAttempt;
    if (wrong != null) {
      _drawConnection(
        canvas,
        size,
        wrong.leftPairId,
        wrong.rightPairId,
        errorColor,
      );
    } else if (selectedLeftPairId != null) {
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
        oldDelegate.mismatchAttempt != mismatchAttempt ||
        oldDelegate.selectedLeftPairId != selectedLeftPairId ||
        oldDelegate.neutralColor != neutralColor;
  }
}
