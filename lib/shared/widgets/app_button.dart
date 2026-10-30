import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_elevation.dart';
import '../../app/theme/app_theme_colors.dart';
import '../../app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, destructive }

/// A chunky, raised game button: a colored face sitting on a darker edge that
/// sinks into it while pressed.
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

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed || !_isEnabled) return;
    setState(() => _isPressed = isPressed);
  }

  void _handlePressed() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final style = _ButtonPalette.resolve(
      colors,
      widget.variant,
      enabled: _isEnabled || widget.isLoading,
    );
    final depth = style.edge == null ? 0.0 : AppDimensions.raisedDepth;
    final pressedOffset = _isPressed && !AppMotion.reduceMotion(context)
        ? depth - 1
        : 0.0;
    final radius = AppDimensions.radiusMd;
    final duration = AppMotion.duration(context, AppMotion.instant);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.easeOut,
        margin: EdgeInsets.only(
          top: pressedOffset,
          bottom: depth - pressedOffset,
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: style.face == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(style.face, Colors.white, 0.14)!,
                    style.face!,
                  ],
                ),
          border: style.border == null
              ? null
              : Border.all(
                  color: style.border!,
                  width: AppDimensions.borderWidth,
                ),
          boxShadow: style.edge == null
              ? null
              : AppElevation.raised(style.edge!, depth: depth - pressedOffset),
        ),
        child: TextButton(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size.fromHeight(AppDimensions.buttonHeight - 4),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStatePropertyAll(AppTypography.button),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: radius),
            ),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStatePropertyAll(style.foreground),
            overlayColor: WidgetStatePropertyAll(
              style.foreground.withValues(alpha: 0.08),
            ),
          ),
          onPressed: _isEnabled ? _handlePressed : null,
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.fast),
            switchInCurve: AppMotion.easeOut,
            switchOutCurve: AppMotion.easeIn,
            child: widget.isLoading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: style.foreground,
                    ),
                  )
                : _ButtonContent(
                    key: ValueKey(widget.label),
                    label: widget.label,
                    leadingIcon: widget.leadingIcon,
                    trailingIcon: widget.trailingIcon,
                    hasShadow: style.textShadow,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPalette {
  final Color? face;
  final Color? edge;
  final Color? border;
  final Color foreground;
  final bool textShadow;

  const _ButtonPalette({
    required this.foreground,
    this.face,
    this.edge,
    this.border,
    this.textShadow = false,
  });

  static _ButtonPalette resolve(
    AppThemeColors colors,
    AppButtonVariant variant, {
    required bool enabled,
  }) {
    if (!enabled) {
      return variant == AppButtonVariant.text
          ? _ButtonPalette(foreground: colors.textMuted)
          : _ButtonPalette(
              face: colors.surfaceElevated,
              edge: colors.border,
              border: colors.border,
              foreground: colors.textMuted,
            );
    }

    return switch (variant) {
      AppButtonVariant.primary => _ButtonPalette(
        face: colors.primary,
        edge: colors.primaryDark,
        border: colors.primaryDark,
        foreground: colors.primaryForeground,
        textShadow: true,
      ),
      AppButtonVariant.secondary => _ButtonPalette(
        face: colors.surfaceElevated,
        edge: colors.borderStrong,
        border: colors.borderStrong,
        foreground: colors.primary,
      ),
      AppButtonVariant.outline => _ButtonPalette(
        face: colors.surface,
        edge: colors.borderStrong,
        border: colors.borderStrong,
        foreground: colors.textPrimary,
      ),
      AppButtonVariant.text => _ButtonPalette(foreground: colors.primary),
      AppButtonVariant.destructive => _ButtonPalette(
        face: colors.error,
        edge: AppElevation.edgeColor(colors.error),
        border: AppElevation.edgeColor(colors.error),
        foreground: Colors.white,
        textShadow: true,
      ),
    };
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool hasShadow;

  const _ButtonContent({
    super.key,
    required this.label,
    required this.hasShadow,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final shadows = hasShadow
        ? const [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1.5),
              blurRadius: 0,
            ),
          ]
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          IconTheme.merge(
            data: IconThemeData(size: 20, shadows: shadows),
            child: leadingIcon!,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(shadows: shadows),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          IconTheme.merge(
            data: IconThemeData(size: 20, shadows: shadows),
            child: trailingIcon!,
          ),
        ],
      ],
    );
  }
}
