import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';
import '../../../app/theme/app_spacing.dart';
import '../application/character_controller.dart';
import '../domain/character_state.dart';
import 'character_assets.dart';
import 'character_speech_bubble.dart';
import 'character_view.dart';

/// Reserved strip that holds the character and its speech bubble. The
/// character walks to the opposite side whenever the game moves to a new
/// phase (new question, waiting on the result, a reaction, game end), so it
/// never sits in the same spot. The bubble always takes the free side.
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

  bool _onRight = false;
  late CharacterState _previous;

  @override
  void initState() {
    super.initState();
    _previous = widget.controller.state.value;
    widget.controller.state.addListener(_onState);
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
    if (moves && mounted) setState(() => _onRight = !_onRight);
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characterWidth = widget.height * CharacterAssets.aspectRatio;
    final bubbleInset = characterWidth + AppSpacing.sm;

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
          duration: AppMotion.duration(
            context,
            const Duration(milliseconds: 750),
          ),
          curve: Curves.easeInOutCubic,
          alignment: _onRight ? Alignment.centerRight : Alignment.centerLeft,
          child: CharacterView(
            controller: widget.controller,
            size: widget.height,
          ),
        ),
      ],
    );
  }
}
