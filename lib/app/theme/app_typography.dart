import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.16,
  );

  static TextStyle get headingLarge => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.18,
  );

  static TextStyle get headingMedium => GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static TextStyle get headingSmall => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.24,
  );

  static TextStyle get title => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.32,
  );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static TextStyle get button => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle get badge => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static TextStyle get displayLarge => display;
  static TextStyle get displayMedium => headingLarge;
  static TextStyle get titleLarge => headingSmall;
  static TextStyle get titleMedium => title;
  static TextStyle get bodyLarge => body;
  static TextStyle get bodyMedium => bodySmall;
  static TextStyle get labelLarge => button;
  static TextStyle get labelSmall => caption;
}

class AppTextStyles {
  final AppThemeColors colors;

  const AppTextStyles(this.colors);

  TextStyle get display =>
      AppTypography.display.copyWith(color: colors.textPrimary);
  TextStyle get headingLarge =>
      AppTypography.headingLarge.copyWith(color: colors.textPrimary);
  TextStyle get headingMedium =>
      AppTypography.headingMedium.copyWith(color: colors.textPrimary);
  TextStyle get headingSmall =>
      AppTypography.headingSmall.copyWith(color: colors.textPrimary);
  TextStyle get title =>
      AppTypography.title.copyWith(color: colors.textPrimary);
  TextStyle get body => AppTypography.body.copyWith(color: colors.textPrimary);
  TextStyle get bodySmall =>
      AppTypography.bodySmall.copyWith(color: colors.textSecondary);
  TextStyle get caption =>
      AppTypography.caption.copyWith(color: colors.textMuted);
  TextStyle get button =>
      AppTypography.button.copyWith(color: colors.textPrimary);
  TextStyle get badge =>
      AppTypography.badge.copyWith(color: colors.textPrimary);

  TextStyle get displayLarge => display;
  TextStyle get displayMedium => headingLarge;
  TextStyle get titleLarge => headingSmall;
  TextStyle get titleMedium => title;
  TextStyle get bodyLarge => body;
  TextStyle get bodyMedium => bodySmall;
  TextStyle get labelLarge => button;
  TextStyle get labelSmall => caption;
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get appTextStyles => AppTextStyles(themeColors);
}
