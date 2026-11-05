import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_elevation.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_header.dart';
import '../../../../shared/widgets/size_reporter.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';
import '../../../character3d/presentation/equipped_cosmetics.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../domain/entities/match_the_following_models.dart';
import 'game_power_up_bar.dart';

class MatchTheFollowingView extends ConsumerStatefulWidget {
  final MatchTheFollowingQuestion? question;
  final void Function(Answer answer)? onSubmit;
  final VoidCallback? onExit;
  final int? coinBalanceOverride;
  final int currentIndex;
  final int totalQuestions;
  final String? title;

  // Backend mode props:
  final MatchBoard? board;
  final void Function(Map<String, String> matches, int mistakes)? onBoardSubmit;
  final String? selectedLeftId;
  final Map<String, String>? confirmedMatches;
  final String? lastWrongAttemptLeftId;
  final String? lastWrongAttemptRightId;
  final void Function(String leftId)? onLeftTap;
  final void Function(String rightId)? onRightTap;

  const MatchTheFollowingView({
    super.key,
    this.question,
    this.onSubmit,
    this.onExit,
    this.coinBalanceOverride,
    this.currentIndex = 0,
    this.totalQuestions = 1,
    this.title,
    this.board,
    this.onBoardSubmit,
    this.selectedLeftId,
    this.confirmedMatches,
    this.lastWrongAttemptLeftId,
    this.lastWrongAttemptRightId,
    this.onLeftTap,
    this.onRightTap,
  }) : assert(currentIndex >= 0),
       assert(totalQuestions > 0),
       assert(
         question != null || board != null,
         'Either question or board must be provided',
       );

  @override
  ConsumerState<MatchTheFollowingView> createState() =>
      _MatchTheFollowingViewState();
}

class _MatchTheFollowingViewState extends ConsumerState<MatchTheFollowingView>
    with TickerProviderStateMixin {
  /// A card is never shorter than this, and grows with its text.
  static const double _minCardHeight = 56;
  static const double _rowGap = 10;

  /// Sizes the character slot from what is left of the screen (see build).
  double? _topHeight;
  double? _bottomHeight;
  static const double _connectorGap = 52;

  late List<MatchPair> _shuffledRight;
  late final AnimationController _entryController;
  late final AnimationController _connectorController;
  late final Animation<double> _connectorCurve;
  late final AnimationController _resultController;
  final Character3dController _character = Character3dController();
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  final _boardKey = GlobalKey();
  final Map<String, GlobalKey> _leftAnchorKeys = {};
  final Map<String, GlobalKey> _rightAnchorKeys = {};
  final Map<String, String> _matches = {};
  Map<String, Offset> _leftAnchors = {};
  Map<String, Offset> _rightAnchors = {};
  bool _measurementScheduled = false;

  String? _selectedLeftPairId;
  String? _selectedRightPairId;
  String? _animatingPairLeftId;
  _MatchFlowPhase _phase = _MatchFlowPhase.playing;
  bool _isHintVisible = false;
  bool _isAutoMatchUsed = false;
  bool _isShuffleUsed = false;

  bool get _isBackendMode => widget.board != null;

  List<MatchPair> get _effectiveLeftPairs {
    if (widget.board != null) {
      return widget.board!.leftItems
          .map((item) => MatchPair(id: item.id, left: item.text, right: ''))
          .toList(growable: false);
    }
    return widget.question?.pairs ?? const [];
  }

  List<MatchPair> get _effectiveRightPairs => _shuffledRight;

  Map<String, String> get _effectiveMatches =>
      _matches.isNotEmpty ? _matches : (widget.confirmedMatches ?? _matches);

  Map<String, String> get _effectiveSolutionMap {
    if (widget.board != null) {
      return widget.board!.solutionMap;
    }
    final map = <String, String>{};
    for (final pair in widget.question?.pairs ?? const <MatchPair>[]) {
      map[pair.id] = pair.id;
    }
    return map;
  }

  String? get _effectiveSelectedLeftId {
    final candidate =
        _selectedLeftPairId ?? (_isBackendMode ? widget.selectedLeftId : null);
    if (candidate != null && _effectiveMatches.containsKey(candidate)) {
      return null;
    }
    return candidate;
  }

  @override
  void initState() {
    super.initState();
    if (widget.board != null) {
      // Backend provides right_items in pre-shuffled server order.
      // Must display exactly in server-provided order.
      _shuffledRight = widget.board!.rightItems
          .map((item) => MatchPair(id: item.id, left: '', right: item.text))
          .toList(growable: false);
    } else if (widget.question != null) {
      _shuffledRight = List.of(widget.question!.pairs);
      _shuffledRight.shuffle(Random(widget.question!.id.hashCode));
    } else {
      _shuffledRight = [];
    }

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..forward();

    _connectorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _connectorCurve = CurvedAnimation(
      parent: _connectorController,
      curve: Curves.easeOut,
    );

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
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
    if (widget.board != null &&
        oldWidget.board?.questionCode != widget.board?.questionCode) {
      // Transitioning to a new backend board
      _shuffledRight = widget.board!.rightItems
          .map((item) => MatchPair(id: item.id, left: '', right: item.text))
          .toList(growable: false);
      _matches.clear();
      _selectedLeftPairId = null;
      _selectedRightPairId = null;
      _animatingPairLeftId = null;
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
      _shakeController.reset();
    } else if (widget.confirmedMatches != null &&
        widget.confirmedMatches != oldWidget.confirmedMatches) {
      final newlyAdded = widget.confirmedMatches!.keys.firstWhere(
        (k) => !(oldWidget.confirmedMatches?.containsKey(k) ?? false),
        orElse: () => '',
      );
      if (newlyAdded.isNotEmpty) {
        _animatingPairLeftId = newlyAdded;
        _connectorController.forward(from: 0);
      }
    } else if (widget.question != null &&
        oldWidget.question?.id != widget.question?.id) {
      _shuffledRight = List.of(widget.question!.pairs);
      _shuffledRight.shuffle(Random(widget.question!.id.hashCode));
      _matches.clear();
      _selectedLeftPairId = null;
      _selectedRightPairId = null;
      _animatingPairLeftId = null;
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
      _shakeController.reset();
    }

    if (widget.lastWrongAttemptLeftId != null &&
        widget.lastWrongAttemptLeftId != oldWidget.lastWrongAttemptLeftId) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _connectorController.dispose();
    _resultController.dispose();
    _character.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleLeftTap(String pairId) {
    if (_isLocked) return;

    widget.onLeftTap?.call(pairId);
    HapticFeedback.selectionClick();

    // If Right card is already selected -> complete the pair!
    if (_selectedRightPairId != null) {
      final rightId = _selectedRightPairId!;
      ref.read(gameAudioServiceProvider).play(GameSound.matchConnect);
      setState(() {
        _matches.removeWhere((l, r) => l == pairId || r == rightId);
        _matches[pairId] = rightId;
        _animatingPairLeftId = pairId;
        _selectedLeftPairId = null;
        _selectedRightPairId = null;
      });
      _connectorController.forward(from: 0);
      _character.twirl();
      return;
    }

    // No Right card selected: selection / toggle / disconnect
    ref.read(gameAudioServiceProvider).play(GameSound.answerSelect);
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
      _selectedRightPairId = null;
    });
  }

  void _handleRightTap(String pairId) {
    if (_isLocked) return;

    widget.onRightTap?.call(pairId);
    HapticFeedback.selectionClick();

    // If Left card is already selected -> complete the pair!
    if (_selectedLeftPairId != null) {
      final leftId = _selectedLeftPairId!;
      ref.read(gameAudioServiceProvider).play(GameSound.matchConnect);
      setState(() {
        _matches.removeWhere((l, r) => l == leftId || r == pairId);
        _matches[leftId] = pairId;
        _animatingPairLeftId = leftId;
        _selectedLeftPairId = null;
        _selectedRightPairId = null;
      });
      _connectorController.forward(from: 0);
      _character.twirl();
      return;
    }

    // No Left card selected: selection / toggle / disconnect
    ref.read(gameAudioServiceProvider).play(GameSound.answerSelect);
    setState(() {
      final matchedLeftId = _leftPairIdForRight(pairId);
      final hadMatch = matchedLeftId != null;
      if (_selectedRightPairId == pairId && !hadMatch) {
        _selectedRightPairId = null;
        return;
      }

      if (hadMatch) {
        _matches.remove(matchedLeftId);
      }
      _selectedRightPairId = pairId;
      _selectedLeftPairId = null;
    });
  }

  bool get _isLocked => _phase == _MatchFlowPhase.submitting;

  /// The last board of the game: its button says "Submit" instead of "Next".
  bool get _isLastBoard => widget.currentIndex >= widget.totalQuestions - 1;

  int get _correctPairCount {
    final solution = _effectiveSolutionMap;
    var count = 0;
    for (final entry in _matches.entries) {
      if (solution[entry.key] == entry.value) {
        count++;
      }
    }
    return count;
  }

  int get _availableCoins {
    return widget.coinBalanceOverride ??
        ref.watch(walletControllerProvider).valueOrNull?.coins ??
        0;
  }

  void _submitIfReady() {
    final pairs = _effectiveLeftPairs;
    if (_matches.length != pairs.length || _isLocked) return;
    HapticFeedback.mediumImpact();
    if (_correctPairCount == pairs.length) {
      ref.read(gameAudioServiceProvider).play(GameSound.correct);
    } else {
      ref.read(gameAudioServiceProvider).play(GameSound.wrong);
    }
    setState(() {
      _phase = _MatchFlowPhase.submitting;
      _selectedLeftPairId = null;
      _selectedRightPairId = null;
    });
    _deliverBoard();
  }

  void _showHint() {
    if (_isLocked || _isHintVisible) return;
    setState(() => _isHintVisible = true);
  }

  void _autoMatchOne() {
    if (_isLocked || _isAutoMatchUsed) return;
    String? leftToMatch;
    String? rightToMatch;

    final solution = _effectiveSolutionMap;
    for (final entry in solution.entries) {
      if (_matches[entry.key] != entry.value) {
        leftToMatch = entry.key;
        rightToMatch = entry.value;
        break;
      }
    }
    if (leftToMatch == null || rightToMatch == null) return;

    ref.read(gameAudioServiceProvider).play(GameSound.matchConnect);
    setState(() {
      _isAutoMatchUsed = true;
      _matches.removeWhere(
        (leftPairId, rightPairId) =>
            rightPairId == rightToMatch || leftPairId == leftToMatch,
      );
      _matches[leftToMatch!] = rightToMatch!;
      _animatingPairLeftId = leftToMatch;
      _selectedLeftPairId = null;
      _selectedRightPairId = null;
    });
    _connectorController.forward(from: 0);
  }

  void _shuffleAnswers() {
    if (_isLocked || _isShuffleUsed) return;
    if (_isBackendMode) return; // Server order is strictly authoritative

    setState(() {
      _isShuffleUsed = true;
      _shuffledRight.shuffle(
        Random((widget.question?.id.hashCode ?? 0) + _matches.length + 17),
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

  /// Hands the finished board to the game. Whether each pair was right is not
  /// shown here: the results screen reviews every board at the end.
  void _deliverBoard() {
    if (_isBackendMode) {
      final wrongCount = _effectiveLeftPairs.length - _correctPairCount;
      widget.onBoardSubmit?.call(Map.of(_matches), wrongCount);
    } else if (widget.question != null) {
      widget.onSubmit?.call(
        MatchTheFollowingAnswer(
          questionId: widget.question!.id,
          matchedPairIds: Map.of(_matches),
        ),
      );
    }
  }

  /// Height of every row: the taller of its two labels, never below the
  /// minimum. Long answers get the room they need; short ones stay compact.
  List<double> _rowHeights(
    BuildContext context,
    List<MatchPair> left,
    List<MatchPair> right,
    double cardWidth,
  ) {
    final style = context.appTextStyles.bodySmall.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double textHeight(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 4,
        textAlign: TextAlign.center,
      )..layout(maxWidth: max(1.0, cardWidth - 20 - 4));
      final h = painter.height;
      painter.dispose();
      return h;
    }

    return [
      for (var i = 0; i < left.length; i++)
        max(
          _minCardHeight,
          max(
                textHeight(left[i].left),
                i < right.length ? textHeight(right[i].right) : 0,
              ) +
              24, // padding and breathing room
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final leftPairs = _effectiveLeftPairs;
    final rightPairs = _effectiveRightPairs;
    final matches = _effectiveMatches;
    final matchedCount = matches.length;
    final totalPairs = leftPairs.length;
    final allMatched = totalPairs > 0 && matchedCount == totalPairs;

    final promptText =
        widget.board?.prompt ?? widget.question?.prompt ?? 'Match each concept';

    return ColoredBox(
      key: const Key('match_it_view'),
      color: colors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            const verticalPadding = AppSpacing.md + AppSpacing.lg;
            final boardWidth = viewport.maxWidth - AppSpacing.screenPadding * 2;
            final cardWidth = (boardWidth - _connectorGap) / 2;
            final rowHeights = _rowHeights(
              context,
              leftPairs,
              rightPairs,
              cardWidth,
            );
            final boardHeight = rowHeights.fold<double>(
              0,
              (sum, h) => sum + h + _rowGap,
            );
            // What is left once the header, prompt, pairs, power-ups and
            // button have their room: the character fills it (up to a limit),
            // or is left out when there is not enough.
            final free = (_topHeight == null || _bottomHeight == null)
                ? 0.0
                : viewport.maxHeight -
                      verticalPadding -
                      _topHeight! -
                      _bottomHeight! -
                      AppSpacing.md * 2;
            final showCharacter = free >= 96;
            final characterHeight = free.clamp(96.0, 240.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewport.maxHeight - verticalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizeReporter(
                      onSize: (size) {
                        if (_topHeight == null ||
                            (_topHeight! - size.height).abs() > 0.5) {
                          setState(() => _topHeight = size.height);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GameHeader(
                            title: 'Match It',
                            currentIndex: widget.currentIndex,
                            totalQuestions: widget.totalQuestions,
                            progress: widget.totalQuestions == 0
                                ? 0.0
                                : (widget.currentIndex + 1) /
                                      widget.totalQuestions,
                            coins: _availableCoins,
                            semanticLabel: 'Match It progress',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            promptText,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showCharacter)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Center(
                          child: CharacterGlow(
                            child: Character3dView(
                              width: characterHeight * 0.85,
                              height: characterHeight,
                              state: Character3dState.idle,
                              controller: _character,
                              cosmetics: equippedCosmetics(context),
                              initialAction: Character3dAction.think,
                              placeholder: const SizedBox.shrink(),
                              arrive: true,
                              fallback: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    SizeReporter(
                      onSize: (size) {
                        if (_bottomHeight == null ||
                            (_bottomHeight! - size.height).abs() > 0.5) {
                          setState(() => _bottomHeight = size.height);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                        key: const Key(
                                          'match_connection_layer',
                                        ),
                                        child: AnimatedBuilder(
                                          animation: _connectorController,
                                          builder: (context, _) {
                                            return CustomPaint(
                                              painter: _MatchConnectionPainter(
                                                connectorAnimation:
                                                    _connectorCurve,
                                                resultAnimation:
                                                    _resultController,
                                                leftPairs: leftPairs,
                                                rightPairs: rightPairs,
                                                matches: matches,
                                                solutionMap:
                                                    _effectiveSolutionMap,
                                                animatingPairLeftId:
                                                    _animatingPairLeftId,
                                                leftAnchors: _leftAnchors,
                                                rightAnchors: _rightAnchors,
                                                hasSubmitted: false,
                                                selectedLeftPairId:
                                                    _selectedLeftPairId ??
                                                    _effectiveSelectedLeftId,
                                                selectedRightPairId:
                                                    _selectedRightPairId,
                                                cardHeight:
                                                    boardHeight /
                                                        max(1, totalPairs) -
                                                    _rowGap,
                                                rowGap: _rowGap,
                                                connectorGap: _connectorGap,
                                                successColor: colors.success,
                                                errorColor: colors.error,
                                                selectedColor: colors.secondary,
                                                neutralColor:
                                                    colors.borderStrong,
                                                isBackendMode: _isBackendMode,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _shakeAnimation,
                                      builder: (context, _) {
                                        final shakeVal = _shakeAnimation.value;
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  for (final indexed
                                                      in leftPairs.indexed)
                                                    _EntryMotion(
                                                      controller:
                                                          _entryController,
                                                      index: indexed.$1,
                                                      side: _MatchCardSide.left,
                                                      child: _MatchConceptCard(
                                                        key: Key(
                                                          'match-left-${indexed.$2.id}',
                                                        ),
                                                        anchorKey: _anchorKey(
                                                          _leftAnchorKeys,
                                                          indexed.$2.id,
                                                        ),
                                                        anchorSemanticKey: Key(
                                                          'match-left-anchor-${indexed.$2.id}',
                                                        ),
                                                        height:
                                                            rowHeights[indexed
                                                                .$1],
                                                        label: indexed.$2.left,
                                                        side:
                                                            _MatchCardSide.left,
                                                        state: _leftState(
                                                          indexed.$2.id,
                                                        ),
                                                        shakeOffset:
                                                            widget.lastWrongAttemptLeftId ==
                                                                indexed.$2.id
                                                            ? shakeVal
                                                            : 0,
                                                        onTap: _isLocked
                                                            ? null
                                                            : () =>
                                                                  _handleLeftTap(
                                                                    indexed
                                                                        .$2
                                                                        .id,
                                                                  ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              width: _connectorGap,
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  for (final indexed
                                                      in rightPairs.indexed)
                                                    _EntryMotion(
                                                      key: ValueKey(
                                                        'match-right-entry-${indexed.$2.id}',
                                                      ),
                                                      controller:
                                                          _entryController,
                                                      index: indexed.$1,
                                                      side:
                                                          _MatchCardSide.right,
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
                                                        height:
                                                            rowHeights[indexed
                                                                .$1],
                                                        label: indexed.$2.right,
                                                        side: _MatchCardSide
                                                            .right,
                                                        state: _rightState(
                                                          indexed.$2.id,
                                                        ),
                                                        shakeOffset:
                                                            widget.lastWrongAttemptRightId ==
                                                                indexed.$2.id
                                                            ? shakeVal
                                                            : 0,
                                                        onTap: _isLocked
                                                            ? null
                                                            : () =>
                                                                  _handleRightTap(
                                                                    indexed
                                                                        .$2
                                                                        .id,
                                                                  ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (_isHintVisible) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppCard(
                              variant: AppCardVariant.tinted,
                              tintColor: colors.primary,
                              borderRadius: AppDimensions.radiusLg,
                              child: Text(
                                widget.board?.hint ??
                                    'Start with the clearest concept, then remove any pair you are unsure about before final submit.',
                                style: context.appTextStyles.bodyMedium
                                    .copyWith(color: colors.textPrimary),
                              ),
                            ),
                          ],
                          ...[
                            const SizedBox(height: AppSpacing.md),
                            GamePowerUpBar(
                              isDense: true,
                              coinBalanceOverride: widget.coinBalanceOverride,
                              isDisabled: _isLocked,
                              actions: [
                                GamePowerUpAction(
                                  id: 'match-hint',
                                  label: 'Hint',
                                  description:
                                      'Show a pairing strategy for this board.',
                                  coinCost: 10,
                                  icon: Icons.lightbulb_outline,
                                  isUsed: _isHintVisible,
                                  onUse: _showHint,
                                ),
                                GamePowerUpAction(
                                  id: 'auto-match',
                                  label: 'Auto',
                                  description:
                                      'Correctly match one remaining pair.',
                                  coinCost: 30,
                                  icon: Icons.auto_awesome_rounded,
                                  isDisabled: _isLocked,
                                  isUsed: _isAutoMatchUsed,
                                  onUse: _autoMatchOne,
                                ),
                                GamePowerUpAction(
                                  id: 'shuffle',
                                  label: 'Shuffle',
                                  description: _isBackendMode
                                      ? 'Answer order is fixed by the server.'
                                      : 'Shuffle the answer side.',
                                  coinCost: 15,
                                  icon: Icons.shuffle_rounded,
                                  isDisabled: _isBackendMode || _isLocked,
                                  isUsed: _isShuffleUsed,
                                  onUse: _shuffleAnswers,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AnimatedScale(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.normal,
                            ),
                            curve: AppMotion.easeOut,
                            scale: allMatched ? 1 : 0.98,
                            child: AnimatedOpacity(
                              duration: AppMotion.duration(
                                context,
                                AppMotion.normal,
                              ),
                              opacity: allMatched ? 1 : 0.58,
                              child: AppButton(
                                key: const Key('match_next_button'),
                                label: _isLastBoard ? 'Submit' : 'Next',
                                isLoading: _phase == _MatchFlowPhase.submitting,
                                onPressed: allMatched ? _submitIfReady : null,
                              ),
                            ),
                          ),
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
    );
  }

  _MatchCardState _leftState(String pairId) {
    if (_matches.containsKey(pairId)) {
      return _MatchCardState.matched;
    }
    if (_selectedLeftPairId == pairId ||
        (_selectedLeftPairId == null && _effectiveSelectedLeftId == pairId)) {
      return _MatchCardState.selected;
    }
    return _MatchCardState.neutral;
  }

  _MatchCardState _rightState(String pairId) {
    final matchedLeftPairId = _leftPairIdForRight(pairId);
    if (matchedLeftPairId != null) {
      return _MatchCardState.matched;
    }
    if (_selectedRightPairId == pairId) {
      return _MatchCardState.selected;
    }
    return _MatchCardState.neutral;
  }

  String? _leftPairIdForRight(String rightPairId) {
    final matches = _effectiveMatches;
    for (final entry in matches.entries) {
      if (entry.value == rightPairId) return entry.key;
    }
    return null;
  }
}

enum _MatchFlowPhase { playing, submitting }

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
  final double height;
  final _MatchCardSide side;
  final _MatchCardState state;
  final double shakeOffset;
  final VoidCallback? onTap;

  const _MatchConceptCard({
    super.key,
    required this.anchorKey,
    required this.anchorSemanticKey,
    required this.label,
    required this.height,
    required this.side,
    required this.state,
    this.shakeOffset = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final indicator = _statusIndicator(colors);

    final cardContent = Opacity(
      opacity: onTap == null && state != _MatchCardState.correct ? 0.9 : 1,
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
                height: height,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _background(colors),
                  borderRadius: AppDimensions.radiusMd,
                  border: Border.all(
                    color: _border(colors),
                    width: state == _MatchCardState.neutral ? 1 : 1.6,
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
                            maxLines: 4,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
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
    );

    return Padding(
      padding: const EdgeInsets.only(
        bottom: _MatchTheFollowingViewState._rowGap,
      ),
      child: shakeOffset != 0
          ? Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: cardContent,
            )
          : cardContent,
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
                : (state == _MatchCardState.correct
                      ? [
                          BoxShadow(
                            color: colors.success.withValues(alpha: 0.32),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : AppElevation.shadows(colors, 1)),
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
      _MatchCardState.correct => colors.success.withValues(alpha: 0.08),
      _MatchCardState.wrong => colors.error.withValues(alpha: 0.08),
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
          color: colors.primary.withValues(alpha: 0.20),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      );
    } else if (state == _MatchCardState.correct) {
      shadows.add(
        BoxShadow(
          color: colors.success.withValues(alpha: 0.18),
          blurRadius: 10,
        ),
      );
    } else if (state == _MatchCardState.wrong) {
      shadows.add(
        BoxShadow(color: colors.error.withValues(alpha: 0.20), blurRadius: 10),
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
  final Map<String, String>? solutionMap;
  final String? animatingPairLeftId;
  final Map<String, Offset> leftAnchors;
  final Map<String, Offset> rightAnchors;
  final bool hasSubmitted;
  final String? selectedLeftPairId;
  final String? selectedRightPairId;
  final double cardHeight;
  final double rowGap;
  final double connectorGap;
  final Color successColor;
  final Color errorColor;
  final Color selectedColor;
  final Color neutralColor;
  final bool isBackendMode;

  _MatchConnectionPainter({
    required this.connectorAnimation,
    required this.resultAnimation,
    required this.leftPairs,
    required this.rightPairs,
    required this.matches,
    this.solutionMap,
    this.animatingPairLeftId,
    required this.leftAnchors,
    required this.rightAnchors,
    required this.hasSubmitted,
    required this.selectedLeftPairId,
    this.selectedRightPairId,
    required this.cardHeight,
    required this.rowGap,
    required this.connectorGap,
    required this.successColor,
    required this.errorColor,
    required this.selectedColor,
    required this.neutralColor,
    this.isBackendMode = false,
  }) : super(repaint: Listenable.merge([connectorAnimation, resultAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final entries = matches.entries.toList(growable: false);
    final solution = solutionMap ?? const {};
    for (final indexedEntry in entries.indexed) {
      final index = indexedEntry.$1;
      final entry = indexedEntry.$2;
      final isCorrect = solution.isNotEmpty
          ? solution[entry.key] == entry.value
          : entry.key == entry.value;
      final resultColor = isCorrect ? successColor : errorColor;

      final double progress;
      final Color color;

      if (!hasSubmitted) {
        color = selectedColor;
        if (animatingPairLeftId == entry.key &&
            connectorAnimation.value < 1.0) {
          progress = connectorAnimation.value;
        } else {
          progress = 1.0;
        }
      } else {
        final evaluationProgress =
            ((resultAnimation.value * entries.length) - index)
                .clamp(0.0, 1.0)
                .toDouble();
        color = Color.lerp(
          selectedColor,
          resultColor,
          Curves.easeOut.transform(evaluationProgress),
        )!;
        progress = evaluationProgress;
      }

      _drawConnection(canvas, size, entry.key, entry.value, color, progress);
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

    final dx = (end.dx - start.dx).abs();
    final controlOffset = dx * 0.5;
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

    // Subtle ambient glow behind connection line
    if (color == successColor || color == selectedColor) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(visiblePath, glowPaint);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(visiblePath, paint);
  }

  double _leftX(Size size) => (size.width - connectorGap) / 2;

  double _rightX(Size size) => (size.width + connectorGap) / 2;

  double _rowCenterY(int index) =>
      index * (cardHeight + rowGap) + cardHeight / 2;

  @override
  bool shouldRepaint(covariant _MatchConnectionPainter oldDelegate) {
    return oldDelegate.matches != matches ||
        oldDelegate.solutionMap != solutionMap ||
        oldDelegate.animatingPairLeftId != animatingPairLeftId ||
        oldDelegate.leftAnchors != leftAnchors ||
        oldDelegate.rightAnchors != rightAnchors ||
        oldDelegate.hasSubmitted != hasSubmitted ||
        oldDelegate.selectedLeftPairId != selectedLeftPairId ||
        oldDelegate.selectedRightPairId != selectedRightPairId ||
        oldDelegate.neutralColor != neutralColor;
  }
}
