import 'package:flutter/material.dart';

import 'character_3d_view.dart';
import 'character_glow.dart';
import 'equipped_cosmetics.dart';

/// The picture at the top of a results card: the 3D character reacting to how
/// the game went. A cheer for a great game, applause for a good one, and a
/// disappointed stance for a poor one. A still picture of the character shows
/// while it loads, and [trophy] (the original emblem) whenever 3D cannot run.
class ResultMascot extends StatelessWidget {
  /// The game was lost outright (nothing correct, or ended early).
  final bool unsuccessful;

  /// Share of correct answers, 0..1.
  final double accuracy;
  final Widget trophy;

  const ResultMascot({
    super.key,
    required this.unsuccessful,
    required this.accuracy,
    required this.trophy,
  });

  static const double size = 150;

  /// How the character reacts: >= 80% cheers, 50-79% applauds, less looks sad.
  static Character3dAction reaction({
    required bool unsuccessful,
    required double accuracy,
  }) {
    if (unsuccessful || accuracy < 0.5) return Character3dAction.sad;
    return accuracy >= 0.8 ? Character3dAction.cheer : Character3dAction.clap;
  }

  @override
  Widget build(BuildContext context) {
    final action = reaction(unsuccessful: unsuccessful, accuracy: accuracy);
    final sad = action == Character3dAction.sad;
    // The glow takes the colour of the mood: warm for a win, cool when sad.
    return CharacterGlow(
      color: sad ? const Color(0xFF6C86FF) : const Color(0xFFFFC83A),
      strength: sad ? 0.8 : 1,
      child: Character3dView(
        width: size,
        height: size,
        state: Character3dState.idle,
        initialAction: action,
        cosmetics: equippedCosmetics(context),
        placeholder: const Character3dPoster(height: size),
        fallback: SizedBox(
          height: size,
          child: Center(child: trophy),
        ),
      ),
    );
  }
}
