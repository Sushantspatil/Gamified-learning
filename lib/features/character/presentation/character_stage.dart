import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/character_controller.dart';
import '../domain/character_state.dart';
import 'character_assets.dart';
import 'character_motion.dart';
import 'character_speech_bubble.dart';
import 'character_view.dart';

/// Reserved strip where the character lives and walks.
///
/// With a single still image there are no legs to animate, so walking is a
/// steady-pace stroll with a step cycle built from transforms: a bounce and a
/// side-to-side rock once per step, a slight squash, and the character faces
/// the direction it is heading (mirrored when going left). It stops, pauses,
/// then walks somewhere else. When the game enters a new phase it walks to
/// the other end of the strip. The speech bubble travels with it, on
/// whichever side has more room.
class CharacterStage extends StatefulWidget {
  final CharacterController controller;
  final double height;

  /// Whether the character also wanders on its own while the game is calm.
  /// Game events still make it walk when false.
  final bool wander;

  const CharacterStage({
    super.key,
    required this.controller,
    required this.height,
    this.wander = true,
  });

  @override
  State<CharacterStage> createState() => _CharacterStageState();
}

class _CharacterStageState extends State<CharacterStage>
    with SingleTickerProviderStateMixin {
  /// Entering one of these (from a different state) sends the character
  /// walking to the other end of the strip.
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

  /// Walking speed and stride, in logical pixels.
  static const double _speed = 95;
  static const double _stepLength = 42;
  static const double _bubbleGap = 8;

  /// Idle strolls allowed without game activity, so an unattended screen
  /// eventually stops animating.
  static const int _maxStrolls = 10;

  final math.Random _random = math.Random();
  late final AnimationController _walk;
  late CharacterState _previous;
  Timer? _pause;

  /// Position along the strip, 0 (left end) .. 1 (right end).
  double _from = 0;
  double _to = 0;
  double _range = 250; // px the character can travel; set from layout
  bool _walking = false;
  bool _facingLeft = false;
  int _strolls = 0;

  double get _fraction => _walking
      ? _from + (_to - _from) * Curves.easeInOutSine.transform(_walk.value)
      : _to;

  @override
  void initState() {
    super.initState();
    _walk = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _arrive();
      });
    _previous = widget.controller.state.value;
    widget.controller.state.addListener(_onState);
    _schedulePause();
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

  void _onState() {
    final next = widget.controller.state.value;
    final moves = next != _previous && _moveOn.contains(next);
    _previous = next;
    if (moves) {
      _strolls = 0;
      _walkTo(_fraction > 0.5 ? 0 : 1);
    }
  }

  void _walkTo(double target) {
    if (!mounted) return;
    _pause?.cancel();
    final current = _fraction;
    final distance = (target - current).abs() * _range;
    _from = current;
    _to = target;
    if (distance < 4 || CharacterMotion.reduce(context)) {
      _walk.stop();
      setState(() => _walking = false);
      _schedulePause();
      return;
    }
    _facingLeft = target < current;
    _walk.duration = Duration(milliseconds: (distance / _speed * 1000).round());
    setState(() => _walking = true);
    _walk.forward(from: 0);
  }

  void _arrive() {
    if (!mounted) return;
    setState(() => _walking = false);
    _schedulePause();
  }

  /// Stand still for a moment, then (if the game is calm) stroll again.
  void _schedulePause() {
    _pause?.cancel();
    if (!widget.wander || _strolls >= _maxStrolls) return;
    _pause = Timer(Duration(milliseconds: 1200 + _random.nextInt(1400)), () {
      final state = widget.controller.state.value;
      final calm =
          state == CharacterState.idle || state == CharacterState.thinking;
      if (!mounted || !calm || CharacterMotion.reduce(context)) {
        _schedulePause();
        return;
      }
      // A new spot at least a third of the strip away.
      var target = _random.nextDouble();
      for (var i = 0; i < 6 && (target - _to).abs() < 0.35; i++) {
        target = _random.nextDouble();
      }
      if ((target - _to).abs() < 0.35) target = _to > 0.5 ? 0 : 1;
      _strolls++;
      _walkTo(target);
    });
  }

  @override
  void dispose() {
    _pause?.cancel();
    widget.controller.state.removeListener(_onState);
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height;
    final width = height * CharacterAssets.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        _range = math.max(0.0, constraints.maxWidth - width);
        return AnimatedBuilder(
          animation: _walk,
          builder: (context, _) {
            final left = _fraction * _range;
            final roomRight = constraints.maxWidth - left - width - _bubbleGap;
            final roomLeft = left - _bubbleGap;
            final bubbleRight = roomRight >= roomLeft;
            final bubbleWidth = math.min(
              200.0,
              bubbleRight ? roomRight : roomLeft,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: _stepCycle(
                    height,
                    CharacterView(
                      controller: widget.controller,
                      size: height,
                      walking: _walking,
                    ),
                  ),
                ),
                if (bubbleWidth >= 70)
                  Positioned(
                    left: bubbleRight
                        ? left + width + _bubbleGap
                        : left - _bubbleGap - bubbleWidth,
                    top: 0,
                    bottom: 0,
                    width: bubbleWidth,
                    child: Align(
                      alignment: bubbleRight
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: CharacterSpeechBubble(
                        controller: widget.controller,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Walk cycle: one bounce per step, a rock between left and right foot,
  /// a small squash on footfall, and facing the direction of travel.
  Widget _stepCycle(double height, Widget child) {
    if (!_walking) return child;
    final travelled = (_fraction - _from).abs() * _range;
    final phase = travelled / _stepLength; // 1.0 = one step
    final stride = math.sin(phase * math.pi).abs(); // 0 at footfall, 1 mid-step
    final rock = math.sin(phase * math.pi); // sign flips each step
    final matrix = Matrix4.identity()
      ..rotateZ(rock * 0.06)
      ..scaleByDouble(
        (_facingLeft ? -1.0 : 1.0) * (1 + 0.015 * (1 - stride)),
        1 - 0.025 * (1 - stride),
        1,
        1,
      );
    return Transform.translate(
      offset: Offset(0, -stride * height * 0.05),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: matrix,
        child: child,
      ),
    );
  }
}
