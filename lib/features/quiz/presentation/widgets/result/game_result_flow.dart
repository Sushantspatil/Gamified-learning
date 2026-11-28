import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../authentication/presentation/providers/auth_providers.dart';
import '../../../../character3d/presentation/result_mascot.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/result_outcome.dart';
import '../quiz_celebration_overlay.dart';
import 'result_action_bar.dart';
import 'result_progress.dart';
import 'result_share.dart';

/// The whole result of a finished game, the same for every mode: the summary
/// screen, then (only when something changed) the progress screen, with the
/// action bar pinned to the bottom and the celebration on top.
///
/// Each mode builds its own [summary] and says what the "Score details" button
/// opens; this widget does the staging, so all modes behave alike.
class GameResultFlow extends StatefulWidget {
  /// Identifies this result (the session), so a new game gets a new celebration.
  final String sessionKey;
  final CelebrationType celebrationType;

  /// The first screen: usually a `ResultSummary`.
  final Widget summary;

  /// What the progress screen shows after the summary.
  final QuizLevelProgress? levelProgress;
  final int earnedXp;
  final bool leveledUp;

  /// What the share button shares (the card and its message).
  final ShareResult share;

  /// Opens the "Score details" sheet; null hides the button.
  final void Function(BuildContext context)? onDetails;

  final VoidCallback onDone;
  final VoidCallback? onPlayAgain;

  const GameResultFlow({
    super.key,
    required this.sessionKey,
    required this.celebrationType,
    required this.summary,
    required this.earnedXp,
    required this.leveledUp,
    required this.share,
    required this.onDone,
    this.levelProgress,
    this.onDetails,
    this.onPlayAgain,
  });

  @override
  State<GameResultFlow> createState() => _GameResultFlowState();
}

class _GameResultFlowState extends State<GameResultFlow> {
  bool _showProgress = false;

  @override
  Widget build(BuildContext context) {
    return GameCelebrationOverlay(
      key: ValueKey('celebration-${widget.sessionKey}'),
      type: widget.celebrationType,
      child: ResultProgressGate(
        leveledUp: widget.leveledUp,
        builder: (context, hasProgress) {
          final goToProgress = !_showProgress && hasProgress;
          final canReplay = widget.onPlayAgain != null;

          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: AppSpacing.paddingMd,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - AppSpacing.md * 2,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.06, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: KeyedSubtree(
                            key: ValueKey(_showProgress),
                            child: _showProgress
                                ? ResultProgressScreen(
                                    leveledUp: widget.leveledUp,
                                    levelProgress: widget.levelProgress,
                                    earnedXp: widget.earnedXp,
                                  )
                                : widget.summary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              WithPlayerName(
                builder: (playerName) => ResultActionBar(
                  primaryLabel: goToProgress
                      ? 'Continue'
                      : canReplay
                      ? 'Play again'
                      : 'Done',
                  primaryIcon: goToProgress || !canReplay
                      ? null
                      : Icons.replay_rounded,
                  onPrimary: goToProgress
                      ? () => setState(() => _showProgress = true)
                      : (canReplay ? widget.onPlayAgain! : widget.onDone),
                  secondaryLabel: !goToProgress && canReplay ? 'Done' : null,
                  onSecondary: widget.onDone,
                  onShare: () => showShareResultSheet(
                    context,
                    result: widget.share,
                    playerName: playerName,
                  ),
                  onDetails: widget.onDetails == null
                      ? null
                      : () => widget.onDetails!(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The colour of the mood: calm blue after a poor game, fiery for Sudden Death,
/// gold for a brilliant game, the brand colour otherwise.
Color resultAccent(
  BuildContext context, {
  required ResultOutcome outcome,
  required double accuracy,
  bool fiery = false,
}) {
  final colors = context.themeColors;
  if (outcome.subdued) return const Color(0xFF6C86FF);
  if (fiery) return AppColors.streakFire;
  if (accuracy >= 0.9) return colors.warning;
  return colors.primary;
}

/// The character (or, where it cannot run, a trophy / flame) for a result.
Widget resultMascotFor(
  BuildContext context, {
  required bool unsuccessful,
  required double accuracy,
  bool fiery = false,
}) {
  final colors = context.themeColors;
  return ResultMascot(
    mascotSize: 160,
    unsuccessful: unsuccessful,
    accuracy: accuracy.clamp(0.0, 1.0).toDouble(),
    trophy: Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: fiery
              ? [colors.error, colors.violet]
              : [colors.warning, AppColors.accentGold],
        ),
      ),
      child: Icon(
        fiery ? Icons.whatshot : Icons.emoji_events,
        color: colors.textInverse,
        size: 44,
      ),
    ),
  );
}

String? _firstNameOf(String? displayName) {
  final first = displayName?.trim().split(RegExp(r'\s+')).first;
  if (first == null || first.isEmpty) return null;
  return first.length > 14 ? first.substring(0, 14) : first;
}

/// Hands [builder] the player's first name, and builds again when the signed-in
/// user finishes loading. Without a ProviderScope (some tests) there is no name.
class WithPlayerName extends StatelessWidget {
  final Widget Function(String? playerName) builder;

  const WithPlayerName({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final hasScope =
        context
            .getElementForInheritedWidgetOfExactType<
              UncontrolledProviderScope
            >() !=
        null;
    if (!hasScope) return builder(null);
    return Consumer(
      builder: (context, ref, _) => builder(
        _firstNameOf(
          ref.watch(authControllerProvider).valueOrNull?.displayName,
        ),
      ),
    );
  }
}
