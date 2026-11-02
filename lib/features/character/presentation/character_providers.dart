import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/character_controller.dart';

/// One character controller per play session. Auto-disposed (timers and
/// streams cancelled) as soon as the play screen stops watching it, so
/// nothing carries over between games.
final characterControllerProvider = Provider.autoDispose<CharacterController>((
  ref,
) {
  final controller = CharacterController();
  ref.onDispose(controller.dispose);
  return controller;
});
