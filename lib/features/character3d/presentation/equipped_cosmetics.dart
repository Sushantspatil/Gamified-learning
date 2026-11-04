import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rewards/application/rewards_controller.dart';
import 'character_3d_view.dart';

/// What the player has equipped (avatar and profile frame), as the 3D
/// character shows it. Read once; use `ref.watch(rewardsProvider)` yourself
/// where it must follow changes. Returns nothing equipped when there is no
/// provider scope (e.g. a widget shown on its own in a test).
Character3dCosmetics equippedCosmetics(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final state = container.read(rewardsProvider);
    return Character3dCosmetics.fromShopIds(
      avatarId: state.equippedAvatar,
      frameId: state.equippedFrame,
    );
  } catch (_) {
    return Character3dCosmetics.none;
  }
}
