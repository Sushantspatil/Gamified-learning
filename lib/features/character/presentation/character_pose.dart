import 'dart:math' as math;

import 'package:flutter/animation.dart';

import '../domain/character_state.dart';

/// Whole-image transform for one animation frame. Only translate / scale /
/// rotate / opacity values, so everything stays GPU-friendly.
class CharacterPose {
  /// Translation as a fraction of the character height (resolution independent).
  final double dx;
  final double dy;
  final double scaleX;
  final double scaleY;

  /// Radians, positive is clockwise.
  final double rotation;

  /// 0..1 opacity of the coloured glow behind the character.
  final double glow;
  final Color glowColor;

  const CharacterPose({
    this.dx = 0,
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.glow = 0,
    this.glowColor = const Color(0xFF00E5FF),
  });

  static const CharacterPose rest = CharacterPose();
}

const Color _cyan = Color(0xFF00E5FF);
const Color _orange = Color(0xFFFF7A1A);
const Color _dim = Color(0xFF7A7F99);

double _rad(double degrees) => degrees * math.pi / 180;

/// Whether [state] animates continuously (as opposed to playing once).
bool isLoopingState(CharacterState state) => switch (state) {
  CharacterState.idle ||
  CharacterState.thinking ||
  CharacterState.hurry ||
  CharacterState.win ||
  CharacterState.lose => true,
  _ => false,
};

/// How long one pass of [state]'s animation takes.
Duration poseDuration(CharacterState state, {double intensity = 0}) =>
    switch (state) {
      CharacterState.idle => const Duration(milliseconds: 1750),
      CharacterState.thinking => const Duration(milliseconds: 1500),
      CharacterState.hurry => Duration(
        milliseconds: (420 - 220 * intensity).round(),
      ),
      CharacterState.win => const Duration(milliseconds: 450),
      CharacterState.lose => const Duration(milliseconds: 2200),
      CharacterState.intro => const Duration(milliseconds: 1400),
      CharacterState.presenting => const Duration(milliseconds: 900),
      CharacterState.correct => const Duration(milliseconds: 1000),
      CharacterState.wrong => const Duration(milliseconds: 900),
      CharacterState.timeout => const Duration(milliseconds: 1500),
      CharacterState.streak => const Duration(milliseconds: 1500),
    };

/// Pose for [state] at animation value [t] (0..1). Looping states ping-pong
/// (t goes 0→1→0); one-shots run 0→1 once.
CharacterPose characterPose(
  CharacterState state,
  double t, {
  double intensity = 0,
  int streakLevel = 1,
  bool reduceMotion = false,
}) {
  if (reduceMotion) {
    // Static pose; only a steady glow hints at the state.
    return switch (state) {
      CharacterState.correct => const CharacterPose(glow: 0.45),
      CharacterState.wrong => const CharacterPose(glow: 0.2, glowColor: _dim),
      CharacterState.streak => const CharacterPose(
        glow: 0.55,
        glowColor: _orange,
      ),
      CharacterState.win => const CharacterPose(glow: 0.4),
      _ => CharacterPose.rest,
    };
  }

  final sine = math.sin(t * math.pi); // 0→1→0 over the pass
  final wave = math.sin(t * 2 * math.pi); // -1..1

  switch (state) {
    case CharacterState.idle:
      return CharacterPose(
        dx: 0.05 * (t * 2 - 1),
        dy: -0.025 * sine,
        rotation: _rad(2.5) * (t * 2 - 1),
        scaleY: 1 + 0.025 * sine,
      );
    case CharacterState.intro:
      final slide = Curves.easeOutBack.transform((t / 0.6).clamp(0.0, 1.0));
      final gesture = t < 0.6 ? 0.0 : math.sin((t - 0.6) / 0.4 * math.pi);
      return CharacterPose(
        dx: (1 - slide) * -0.7,
        rotation: _rad(2.5) * gesture,
      );
    case CharacterState.presenting:
      return CharacterPose(
        dx: 0.03 * Curves.easeOut.transform(sine),
        rotation: _rad(4) * Curves.easeOut.transform(sine),
        scaleX: 1 + 0.05 * sine,
        scaleY: 1 + 0.05 * sine,
      );
    case CharacterState.thinking:
      return CharacterPose(
        dx: 0.06 * (t * 2 - 1),
        dy: -0.012 * sine,
        rotation: _rad(3) * (t * 2 - 1),
        scaleY: 1 + 0.008 * sine,
      );
    case CharacterState.hurry:
      final k = 0.4 + 0.6 * intensity;
      return CharacterPose(
        dy: -0.02 * k * sine,
        dx: 0.015 * k * (t * 2 - 1),
        rotation: _rad(1.2) * k * (t * 2 - 1),
      );
    case CharacterState.correct:
      return CharacterPose(
        scaleX: 1 + 0.08 * sine,
        scaleY: 1 + 0.08 * sine,
        dy: -0.03 * sine,
        glow: sine,
        glowColor: _cyan,
      );
    case CharacterState.wrong:
      final fade = 1 - t;
      return CharacterPose(
        scaleX: 1 - 0.03 * sine,
        scaleY: 1 - 0.03 * sine,
        rotation: _rad(3) * math.sin(t * 4 * math.pi) * fade,
        glow: 0.25 * sine,
        glowColor: _dim,
      );
    case CharacterState.timeout:
      final sink = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7;
      return CharacterPose(
        dy: 0.02 * Curves.easeOut.transform(sink),
        scaleX: 1 - 0.02 * sink,
        scaleY: 1 - 0.02 * sink,
      );
    case CharacterState.streak:
      final level = streakLevel.clamp(1, 3);
      return CharacterPose(
        scaleX: 1 + (0.06 + 0.03 * level) * sine,
        scaleY: 1 + (0.06 + 0.03 * level) * sine,
        dy: -(0.03 + 0.015 * level) * sine,
        rotation: _rad(2.0 * level) * wave,
        glow: (0.5 + 0.15 * level).clamp(0.0, 1.0) * sine,
        glowColor: _orange,
      );
    case CharacterState.win:
      return CharacterPose(
        dy: -0.035 * sine,
        scaleX: 1 + 0.04 * sine,
        scaleY: 1 + 0.04 * sine,
        glow: 0.35 + 0.25 * sine,
        glowColor: _cyan,
      );
    case CharacterState.lose:
      return CharacterPose(
        rotation: _rad(1.5) * (t * 2 - 1),
        glow: 0.2,
        glowColor: _dim,
      );
  }
}
