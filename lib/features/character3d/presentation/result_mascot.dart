import 'package:flutter/material.dart';

import 'character_3d_view.dart';

/// The picture at the top of a results card: the 3D character walking when the
/// game went well, standing when it did not. Shows [trophy] (the original
/// emblem) while the character loads and whenever it is unavailable.
class ResultMascot extends StatelessWidget {
  final bool unsuccessful;
  final Widget trophy;

  const ResultMascot({
    super.key,
    required this.unsuccessful,
    required this.trophy,
  });

  static const double size = 150;

  @override
  Widget build(BuildContext context) {
    return Character3dView(
      width: size,
      height: size,
      state: unsuccessful ? Character3dState.idle : Character3dState.walk,
      fallback: trophy,
    );
  }
}
