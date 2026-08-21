import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_theme_colors.dart';

class AppAvatar extends StatelessWidget {
  final ImageProvider? image;
  final String? assetPath;
  final IconData fallbackIcon;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? frameColor;

  const AppAvatar({
    super.key,
    this.image,
    this.assetPath,
    this.fallbackIcon = Icons.person_outline,
    this.size = AppDimensions.avatarSizeMd,
    this.backgroundColor,
    this.foregroundColor,
    this.frameColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final provider =
        image ?? (assetPath == null ? null : AssetImage(assetPath!));
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? colors.surfaceElevated,
      foregroundImage: provider,
      child: provider == null
          ? Icon(
              fallbackIcon,
              color: foregroundColor ?? colors.primary,
              size: size * 0.5,
            )
          : null,
    );

    if (frameColor == null) return avatar;

    return Container(
      width: size + 6,
      height: size + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: frameColor!, width: 2),
      ),
      child: avatar,
    );
  }
}
