import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get displayMedium => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get titleLarge => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );
}

class AppTextStyles {
  final AppThemeColors colors;

  const AppTextStyles(this.colors);

  TextStyle get displayLarge => AppTypography.displayLarge.copyWith(color: colors.textPrimary);
  TextStyle get displayMedium => AppTypography.displayMedium.copyWith(color: colors.textPrimary);
  TextStyle get titleLarge => AppTypography.titleLarge.copyWith(color: colors.textPrimary);
  TextStyle get titleMedium => AppTypography.titleMedium.copyWith(color: colors.textPrimary);
  TextStyle get bodyLarge => AppTypography.bodyLarge.copyWith(color: colors.textPrimary);
  TextStyle get bodyMedium => AppTypography.bodyMedium.copyWith(color: colors.textSecondary);
  TextStyle get labelLarge => AppTypography.labelLarge.copyWith(color: colors.textPrimary);
  TextStyle get labelSmall => AppTypography.labelSmall.copyWith(color: colors.textMuted);
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get appTextStyles => AppTextStyles(themeColors);
}
