import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_colors.dart';

/// Game-style type: Fredoka (rounded, chunky) for headings, buttons and
/// numbers; Nunito (rounded, heavy) for reading text.
class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.fredoka(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static TextStyle get headingLarge => GoogleFonts.fredoka(
    fontSize: 29,
    fontWeight: FontWeight.w700,
    height: 1.14,
  );

  static TextStyle get headingMedium => GoogleFonts.fredoka(
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.18,
  );

  static TextStyle get headingSmall => GoogleFonts.fredoka(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.22,
  );

  static TextStyle get title => GoogleFonts.fredoka(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get body => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.45,
  );

  static TextStyle get bodySmall => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.42,
  );

  static TextStyle get caption => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle get button => GoogleFonts.fredoka(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  static TextStyle get badge => GoogleFonts.fredoka(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  static TextStyle get displayLarge => display;
  static TextStyle get displayMedium => headingLarge;
  static TextStyle get titleLarge => headingSmall;
  static TextStyle get titleMedium => title;
  static TextStyle get bodyLarge => body;
  static TextStyle get bodyMedium => bodySmall;
  static TextStyle get labelLarge => button;
  static TextStyle get labelSmall => caption;

  /// Material text theme with the game fonts applied to every role.
  static TextTheme textTheme(TextTheme base) {
    final body = GoogleFonts.nunitoTextTheme(base);
    TextStyle? heading(TextStyle? style) => style == null
        ? null
        : GoogleFonts.fredoka(textStyle: style, fontWeight: FontWeight.w600);
    return body.copyWith(
      displayLarge: heading(body.displayLarge),
      displayMedium: heading(body.displayMedium),
      displaySmall: heading(body.displaySmall),
      headlineLarge: heading(body.headlineLarge),
      headlineMedium: heading(body.headlineMedium),
      headlineSmall: heading(body.headlineSmall),
      titleLarge: heading(body.titleLarge),
      titleMedium: heading(body.titleMedium),
      titleSmall: heading(body.titleSmall),
      labelLarge: heading(body.labelLarge),
    );
  }
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
