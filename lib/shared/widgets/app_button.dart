import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, destructive }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed ||
        widget.onPressed == null ||
        widget.isLoading) {
      return;
    }
    setState(() => _isPressed = isPressed);
  }

  void _handlePressed() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotion(context);
    final colors = context.themeColors;
    final foregroundColor = _foregroundColor(colors, widget.variant);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed && !reduceMotion ? 0.985 : 1,
        duration: AppMotion.duration(context, AppMotion.instant),
        curve: AppMotion.easeOut,
        child: TextButton(
          style: _styleFor(colors, widget.variant),
          onPressed: widget.isLoading || widget.onPressed == null
              ? null
              : _handlePressed,
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.fast),
            switchInCurve: AppMotion.easeOut,
            switchOutCurve: AppMotion.easeIn,
            child: widget.isLoading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: foregroundColor,
                    ),
                  )
                : _ButtonContent(
                    key: ValueKey(widget.label),
                    label: widget.label,
                    leadingIcon: widget.leadingIcon,
                    trailingIcon: widget.trailingIcon,
                  ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _styleFor(AppThemeColors colors, AppButtonVariant variant) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(AppDimensions.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 0),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(AppTypography.button),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppDimensions.radiusMd),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _disabledBackground(colors, variant);
        }
        if (states.contains(WidgetState.pressed)) {
          return _pressedBackground(colors, variant);
        }
        return _backgroundColor(colors, variant);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.textMuted;
        return _foregroundColor(colors, variant);
      }),
      overlayColor: WidgetStatePropertyAll(_overlayColor(colors, variant)),
      side: WidgetStateProperty.resolveWith((states) {
        final borderColor = states.contains(WidgetState.disabled)
            ? colors.border
            : variant == AppButtonVariant.outline
            ? colors.borderStrong
            : Colors.transparent;
        return BorderSide(color: borderColor);
      }),
    );
  }

  Color _backgroundColor(AppThemeColors colors, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => colors.primary,
      AppButtonVariant.secondary => colors.surfaceElevated,
      AppButtonVariant.outline => colors.surface,
      AppButtonVariant.text => Colors.transparent,
      AppButtonVariant.destructive => colors.error,
    };
  }

  Color _pressedBackground(AppThemeColors colors, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => colors.primaryHover,
      AppButtonVariant.secondary => colors.surfaceHover,
      AppButtonVariant.outline => colors.surfaceElevated,
      AppButtonVariant.text => colors.surfaceElevated,
      AppButtonVariant.destructive => colors.error.withValues(alpha: 0.9),
    };
  }

  Color _disabledBackground(AppThemeColors colors, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.destructive => colors.surfaceElevated,
      AppButtonVariant.secondary ||
      AppButtonVariant.outline ||
      AppButtonVariant.text => Colors.transparent,
    };
  }

  Color _foregroundColor(AppThemeColors colors, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => colors.primaryForeground,
      AppButtonVariant.secondary => colors.primaryDark,
      AppButtonVariant.outline => colors.textPrimary,
      AppButtonVariant.text => colors.primary,
      AppButtonVariant.destructive => colors.textInverse,
    };
  }

  Color _overlayColor(AppThemeColors colors, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => colors.primaryForeground.withValues(
        alpha: 0.08,
      ),
      AppButtonVariant.destructive => colors.textInverse.withValues(
        alpha: 0.08,
      ),
      _ => colors.primary.withValues(alpha: 0.08),
    };
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const _ButtonContent({
    super.key,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          IconTheme.merge(
            data: const IconThemeData(size: 18),
            child: leadingIcon!,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          IconTheme.merge(
            data: const IconThemeData(size: 18),
            child: trailingIcon!,
          ),
        ],
      ],
    );
  }
}
