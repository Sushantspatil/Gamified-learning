import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color primaryDark;
  final Color primaryHover;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color violet;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color subjectAccountancy;
  final Color subjectBusinessStudies;
  final Color subjectEconomics;
  final Color inputBackground;
  final Color inputBorder;
  final Color inputPlaceholder;
  final Color cardBackground;
  final Color overlay;
  final Color shadow;
  final Color divider;

  const AppThemeColors({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryDark,
    required this.primaryHover,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.violet,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.subjectAccountancy,
    required this.subjectBusinessStudies,
    required this.subjectEconomics,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputPlaceholder,
    required this.cardBackground,
    required this.overlay,
    required this.shadow,
    required this.divider,
  });

  static const AppThemeColors light = AppThemeColors(
    background: Color(0xFFF3F0FF),
    backgroundSecondary: Color(0xFFE8E1FF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF6F3FF),
    surfaceHover: Color(0xFFEDE8FF),
    textPrimary: Color(0xFF1B1446),
    textSecondary: Color(0xFF4A4378),
    textMuted: Color(0xFF6B6499),
    textInverse: Color(0xFFFFFFFF),
    border: Color(0xFFDED7F8),
    borderStrong: Color(0xFFC2B7EE),
    primary: Color(0xFF7C4DFF),
    primaryDark: Color(0xFF5326D9),
    primaryHover: Color(0xFF6B3CF2),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF00B4D8),
    secondaryForeground: Color(0xFFFFFFFF),
    violet: Color(0xFFC13DE8),
    success: Color(0xFF17B55C),
    warning: Color(0xFFF5A00B),
    error: Color(0xFFEF3D5A),
    info: Color(0xFF0EA5E9),
    subjectAccountancy: Color(0xFF7C4DFF),
    subjectBusinessStudies: Color(0xFFFF9F1C),
    subjectEconomics: Color(0xFF00B4D8),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFD3CAF4),
    inputPlaceholder: Color(0xFF5E578C),
    cardBackground: Color(0xFFFFFFFF),
    overlay: Color(0x991B1446),
    shadow: Color(0x262A1B6B),
    divider: Color(0xFFE6E0FA),
  );

  static const AppThemeColors dark = AppThemeColors(
    background: Color(0xFF0D0A2B),
    backgroundSecondary: Color(0xFF16114A),
    surface: Color(0xFF1D1756),
    surfaceElevated: Color(0xFF282070),
    surfaceHover: Color(0xFF322986),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD2CCFA),
    textMuted: Color(0xFFA39CD9),
    textInverse: Color(0xFF140F3A),
    border: Color(0xFF342B80),
    borderStrong: Color(0xFF4A40A6),
    primary: Color(0xFF8B5CFF),
    primaryDark: Color(0xFF5A2DD4),
    primaryHover: Color(0xFFA07BFF),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF22D3EE),
    secondaryForeground: Color(0xFF06283A),
    violet: Color(0xFFE05CFF),
    success: Color(0xFF3BE37A),
    warning: Color(0xFFFFC83D),
    error: Color(0xFFFF4D6D),
    info: Color(0xFF4CC9FF),
    subjectAccountancy: Color(0xFFB69CFF),
    subjectBusinessStudies: Color(0xFFFFC04D),
    subjectEconomics: Color(0xFF5CE1FF),
    inputBackground: Color(0xFF150F45),
    inputBorder: Color(0xFF4339A0),
    inputPlaceholder: Color(0xFFABA4E3),
    cardBackground: Color(0xFF1D1756),
    overlay: Color(0xCC07051C),
    shadow: Color(0x99050318),
    divider: Color(0xFF2C2472),
  );

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? backgroundSecondary,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
    Color? border,
    Color? borderStrong,
    Color? primary,
    Color? primaryDark,
    Color? primaryHover,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? violet,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? subjectAccountancy,
    Color? subjectBusinessStudies,
    Color? subjectEconomics,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputPlaceholder,
    Color? cardBackground,
    Color? overlay,
    Color? shadow,
    Color? divider,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      violet: violet ?? this.violet,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      subjectAccountancy: subjectAccountancy ?? this.subjectAccountancy,
      subjectBusinessStudies:
          subjectBusinessStudies ?? this.subjectBusinessStudies,
      subjectEconomics: subjectEconomics ?? this.subjectEconomics,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputPlaceholder: inputPlaceholder ?? this.inputPlaceholder,
      cardBackground: cardBackground ?? this.cardBackground,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;

    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      violet: Color.lerp(violet, other.violet, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      subjectAccountancy: Color.lerp(
        subjectAccountancy,
        other.subjectAccountancy,
        t,
      )!,
      subjectBusinessStudies: Color.lerp(
        subjectBusinessStudies,
        other.subjectBusinessStudies,
        t,
      )!,
      subjectEconomics: Color.lerp(
        subjectEconomics,
        other.subjectEconomics,
        t,
      )!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputPlaceholder: Color.lerp(
        inputPlaceholder,
        other.inputPlaceholder,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

extension AppThemeColorsX on BuildContext {
  AppThemeColors get themeColors {
    return Theme.of(this).extension<AppThemeColors>()!;
  }
}
