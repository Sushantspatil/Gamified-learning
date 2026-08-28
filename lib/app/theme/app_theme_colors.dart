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
    background: Color(0xFFFBFCFF),
    backgroundSecondary: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF5F7FB),
    textPrimary: Color(0xFF12152B),
    textSecondary: Color(0xFF4F5874),
    textMuted: Color(0xFF707A98),
    textInverse: Color(0xFFFFFFFF),
    border: Color(0xFFEFF2F7),
    borderStrong: Color(0xFFDDE3EE),
    primary: Color(0xFF6D5DFE),
    primaryDark: Color(0xFF4232C8),
    primaryHover: Color(0xFF5B4CF0),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF00B8D9),
    secondaryForeground: Color(0xFFFFFFFF),
    violet: Color(0xFFB052FF),
    success: Color(0xFF12B981),
    warning: Color(0xFFF6A609),
    error: Color(0xFFE5485E),
    info: Color(0xFF00A7E6),
    subjectAccountancy: Color(0xFF6D5DFE),
    subjectBusinessStudies: Color(0xFFFFA726),
    subjectEconomics: Color(0xFF00B8D9),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFE1E7F2),
    inputPlaceholder: Color(0xFF59637E),
    cardBackground: Color(0xFFFFFFFF),
    overlay: Color(0x9912152B),
    shadow: Color(0x0A111827),
    divider: Color(0xFFEFF2F7),
  );

  static const AppThemeColors dark = AppThemeColors(
    background: Color(0xFF090B18),
    backgroundSecondary: Color(0xFF11162B),
    surface: Color(0xFF171B31),
    surfaceElevated: Color(0xFF222845),
    surfaceHover: Color(0xFF2A3153),
    textPrimary: Color(0xFFF8FAFF),
    textSecondary: Color(0xFFC7CDE3),
    textMuted: Color(0xFF9AA3C0),
    textInverse: Color(0xFF101329),
    border: Color(0xFF2A3153),
    borderStrong: Color(0xFF465078),
    primary: Color(0xFF9D8CFF),
    primaryDark: Color(0xFF7662FF),
    primaryHover: Color(0xFFB3A6FF),
    primaryForeground: Color(0xFF11142F),
    secondary: Color(0xFF5FE7FF),
    secondaryForeground: Color(0xFF072F38),
    violet: Color(0xFFD083FF),
    success: Color(0xFF3DE0B7),
    warning: Color(0xFFFFC75A),
    error: Color(0xFFFF6B86),
    info: Color(0xFF64C8FF),
    subjectAccountancy: Color(0xFFA99CFF),
    subjectBusinessStudies: Color(0xFFFFC04D),
    subjectEconomics: Color(0xFF70E3FF),
    inputBackground: Color(0xFF11162B),
    inputBorder: Color(0xFF384260),
    inputPlaceholder: Color(0xFFB0B8D2),
    cardBackground: Color(0xFF171B31),
    overlay: Color(0xB0000000),
    shadow: Color(0x80000000),
    divider: Color(0xFF2A3153),
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
