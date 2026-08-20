import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_dimensions.dart';
import 'app_theme_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light, AppThemeColors.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark, AppThemeColors.dark);
  }

  static ThemeData _buildTheme(Brightness brightness, AppThemeColors colors) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryForeground,
      secondary: colors.secondary,
      onSecondary: colors.secondaryForeground,
      error: colors.error,
      onError: colors.textInverse,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      dividerColor: colors.divider,
      disabledColor: colors.textMuted.withValues(alpha: 0.45),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: brightness == Brightness.dark ? 0 : 1,
        shadowColor: colors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusMd,
          side: BorderSide(color: colors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: colors.textPrimary),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.surfaceElevated,
          disabledForegroundColor: colors.textMuted,
          foregroundColor: colors.primaryForeground,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.radiusMd,
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        labelStyle: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        hintStyle: AppTypography.bodyMedium.copyWith(color: colors.inputPlaceholder),
        errorStyle: AppTypography.labelSmall.copyWith(color: colors.error),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusSm),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: colors.textPrimary),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusMd),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textMuted;
          return colors.primary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
    );
  }
}
