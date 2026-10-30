import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_elevation.dart';
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
      tertiary: colors.warning,
      error: colors.error,
      onError: colors.textInverse,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceElevated,
      outline: colors.borderStrong,
      outlineVariant: colors.border,
    );

    final baseTextTheme = AppTypography.textTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    final chunkyShape = RoundedRectangleBorder(
      borderRadius: AppDimensions.radiusMd,
    );
    final chunkyBorder = BorderSide(
      color: colors.borderStrong,
      width: AppDimensions.borderWidth,
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
        elevation: 0,
        shadowColor: colors.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusCard,
          side: BorderSide(
            color: colors.border,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headingSmall.copyWith(
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 26),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          highlightColor: colors.primary.withValues(alpha: 0.14),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primaryForeground,
        unselectedLabelColor: colors.textSecondary,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: AppDimensions.radiusCircular,
          boxShadow: AppElevation.raised(colors.primaryDark, depth: 3),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        overlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(alpha: 0.08),
        ),
        labelStyle: AppTypography.button.copyWith(fontSize: 15),
        unselectedLabelStyle: AppTypography.button.copyWith(fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.surfaceElevated,
          disabledForegroundColor: colors.textMuted,
          foregroundColor: colors.primaryForeground,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          shape: chunkyShape,
          side: BorderSide(
            color: colors.primaryDark,
            width: AppDimensions.borderWidth,
          ),
          elevation: 0,
          textStyle: AppTypography.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppDimensions.buttonHeight - 8),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18),
          ),
          shape: WidgetStatePropertyAll(chunkyShape),
          textStyle: WidgetStatePropertyAll(AppTypography.button),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.surfaceElevated;
            }
            if (states.contains(WidgetState.pressed)) {
              return colors.primaryHover;
            }
            return colors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return colors.textMuted;
            return colors.primaryForeground;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: colors.border,
                width: AppDimensions.borderWidth,
              );
            }
            return BorderSide(
              color: colors.primaryDark,
              width: AppDimensions.borderWidth,
            );
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          backgroundColor: colors.surface,
          minimumSize: const Size(0, AppDimensions.buttonHeight - 8),
          shape: chunkyShape,
          side: chunkyBorder,
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: AppTypography.button,
          shape: chunkyShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.primaryForeground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusLg,
          side: BorderSide(
            color: colors.primaryDark,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: AppTypography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        floatingLabelStyle: AppTypography.bodySmall.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: AppTypography.bodySmall.copyWith(
          color: colors.inputPlaceholder,
        ),
        errorStyle: AppTypography.caption.copyWith(color: colors.error),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
        border: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(
            color: colors.inputBorder,
            width: AppDimensions.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(
            color: colors.inputBorder,
            width: AppDimensions.borderWidth,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(
            color: colors.border,
            width: AppDimensions.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(
            color: colors.error,
            width: AppDimensions.borderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.radiusMd,
          borderSide: BorderSide(color: colors.error, width: 2.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated,
        selectedColor: colors.primary,
        labelStyle: AppTypography.badge.copyWith(color: colors.textPrimary),
        secondaryLabelStyle: AppTypography.badge.copyWith(
          color: colors.primaryForeground,
        ),
        side: BorderSide(
          color: colors.borderStrong,
          width: AppDimensions.borderWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusCircular,
        ),
        checkmarkColor: colors.primaryForeground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusMd,
          side: BorderSide(
            color: colors.borderStrong,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.headingSmall.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusLg,
          side: BorderSide(
            color: colors.borderStrong,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.borderRadiusLg),
          ),
          side: BorderSide(
            color: colors.borderStrong,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radiusMd,
          side: BorderSide(
            color: colors.borderStrong,
            width: AppDimensions.borderWidth,
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(chunkyShape),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        titleTextStyle: AppTypography.title.copyWith(
          color: colors.textPrimary,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.radiusMd),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryForeground;
          }
          return colors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.success;
          return colors.surfaceElevated;
        }),
        trackOutlineColor: WidgetStatePropertyAll(colors.borderStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textMuted;
          return colors.primary;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.success;
          return Colors.transparent;
        }),
        side: BorderSide(
          color: colors.borderStrong,
          width: AppDimensions.borderWidth,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceElevated,
        thumbColor: colors.primaryForeground,
        trackHeight: 8,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: AppDimensions.radiusSm,
          border: Border.all(color: colors.borderStrong),
        ),
        textStyle: AppTypography.caption.copyWith(color: colors.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceElevated,
        circularTrackColor: colors.surfaceElevated,
      ),
    );
  }
}
