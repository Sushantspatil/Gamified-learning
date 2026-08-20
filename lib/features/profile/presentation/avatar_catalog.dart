import 'package:flutter/material.dart';

/// Fixed set of preset avatars available before the full avatars/cosmetics
/// system (Step 18 stage 14) is built.
class AvatarCatalog {
  AvatarCatalog._();

  static const Map<String, IconData> icons = {
    'default': Icons.person,
    'fox': Icons.pets,
    'owl': Icons.dark_mode,
    'robot': Icons.smart_toy,
    'ninja': Icons.sports_martial_arts,
    'wizard': Icons.auto_fix_high,
  };

  static IconData iconFor(String avatarId) => icons[avatarId] ?? Icons.person;
}
