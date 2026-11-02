import 'package:flutter/material.dart';

import '../../../app/motion/app_motion.dart';

/// Whether the character honours the OS "remove animations" setting.
///
/// Off by default on purpose: the host is the game's mascot and many phones
/// have animations disabled (developer options, battery saver) without the
/// user meaning to freeze the app's character. Set to true to follow the OS
/// setting strictly (static pose, no strolling, no hops).
class CharacterMotion {
  CharacterMotion._();

  static bool respectReduceMotion = false;

  static bool reduce(BuildContext context) =>
      respectReduceMotion && AppMotion.reduceMotion(context);

  static Duration duration(BuildContext context, Duration d) =>
      reduce(context) ? Duration.zero : d;
}
