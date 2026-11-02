import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'character_motion.dart';
import '../../../app/theme/app_spacing.dart';
import '../application/character_controller.dart';
import '../domain/character_state.dart';
import 'character_assets.dart';
import 'character_speech_bubble.dart';
import 'character_view.dart';

/// Reserved strip that holds the character and its speech bubble.
///
/// The character never stays put: it hops to the opposite side when the game
/// enters a new phase (new question, waiting on the result, a reaction, game
/// end) and, while idle or thinking, strolls to a new spot every few seconds.
/// The bubble always takes the side the character is not on.
class CharacterStage extends StatefulWidget {
  final CharacterController controller;
  final double height;

  const CharacterStage({
    super.key,
    required this.controller,
    required this.height,
  });

  @override
  State<CharacterStage> createState() => _CharacterStageState();
}

class _CharacterStageState extends State<CharacterStage> {
  /// Entering one of these (from a different state) moves the character.
  static const _moveOn = {
    CharacterState.presenting,
    CharacterState.thinking,
    CharacterState.correct,
    CharacterState.wrong,
    CharacterState.timeout,
    CharacterState.streak,
    CharacterState.win,
    CharacterState.lose,
  };

  static const Duration _strollEvery = Duration(milliseconds: 2800);
  static const Duration _travel = Duration(milliseconds: 750);

  /// Strolls allowed without any game activity (~35 s), so an unattended
  /// screen eventually stops animating.
  static const int _maxStrolls = 12;

  final math.Random _random = math.Random();

  /// Horizontal position, -1 (left edge) .. 1 (right edge).
  double _x = -1;

  /// Bumped per move; restarts the hop animation.
  int _moves = 0;
  int _strolls = 0;
  Timer? _stroll;
  late CharacterState _previous;

  bool get _onRight => _x > 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.controller.state.value;
    widget.controller.state.addListener(_onState);
    _scheduleStroll();
  }

  @override
  void didUpdateWidget(covariant CharacterStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.removeListener(_onState);
      widget.controller.state.addListener(_onState);
      _previous = widget.controller.state.value;
    }
  }

  void _moveTo(double x) {
    if (!mounted) return;
    setState(() {
      _x = x.clamp(-1.0, 1.0);
      _moves++;
    });
    _scheduleStroll();
  }

  void _onState() {
    final next = widget.controller.state.value;
    final moves = next != _previous && _moveOn.contains(next);
    _previous = next;
    if (moves) {
      _strolls = 0;
      _moveTo(_onRight ? -1 : 1);
    }
  }

  /// Idle wandering: only while calm, and never with reduce-motion.
  void _scheduleStroll() {
    _stroll?.cancel();
    if (_strolls >= _maxStrolls) return;
    _stroll = Timer(_strollEvery, () {
      final state = widget.controller.state.value;
      final calm =
          state == CharacterState.idle || state == CharacterState.thinking;
      if (mounted && calm && !CharacterMotion.reduce(context)) {
        // Go to a new spot on the other half of the strip.
        final distance = 0.4 + _random.nextDouble() * 0.6;
        _strolls++;
        _moveTo(_onRight ? -distance : distance);
      } else {
        _scheduleStroll();
      }
    });
  }

  @override
  void dispose() {
    _stroll?.cancel();
    widget.controller.state.removeListener(_onState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterWidth = widget.height * CharacterAssets.aspectRatio;
    final bubbleInset = characterWidth + AppSpacing.sm;
    final reduceMotion = CharacterMotion.reduce(context);

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: _onRight ? 0 : bubbleInset,
            right: _onRight ? bubbleInset : 0,
          ),
          child: Align(
            alignment: _onRight ? Alignment.centerLeft : Alignment.centerRight,
            child: CharacterSpeechBubble(controller: widget.controller),
          ),
        ),
        AnimatedAlign(
          duration: CharacterMotion.duration(context, _travel),
          curve: Curves.easeInOutCubic,
          alignment: Alignment(_x, 0),
          // Two small hops while travelling, like steps.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_moves),
            tween: Tween(begin: 0, end: 1),
            duration: CharacterMotion.duration(context, _travel),
            builder: (context, t, child) => Transform.translate(
              offset: Offset(
                0,
                reduceMotion
                    ? 0
                    : -math.sin(t * 4 * math.pi).abs() *
                          widget.height *
                          0.06 *
                          (1 - t),
              ),
              child: child,
            ),
            child: CharacterView(
              controller: widget.controller,
              size: widget.height,
            ),
          ),
        ),
      ],
    );
  }
}
