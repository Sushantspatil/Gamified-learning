import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/motion/app_motion.dart';
import '../../app/theme/app_theme_colors.dart';

enum AppButtonVariant {
  primary,
  destructive,
}

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed || widget.onPressed == null || widget.isLoading) return;
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
    final buttonStyle = switch (widget.variant) {
      AppButtonVariant.primary => null,
      AppButtonVariant.destructive => ElevatedButton.styleFrom(
          backgroundColor: colors.error,
          foregroundColor: colors.textInverse,
          disabledBackgroundColor: colors.error.withValues(alpha: 0.48),
          disabledForegroundColor: colors.textInverse.withValues(alpha: 0.72),
        ),
    };

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed && !reduceMotion ? 0.985 : 1,
        duration: AppMotion.duration(context, AppMotion.instant),
        curve: AppMotion.easeOut,
        child: ElevatedButton(
          style: buttonStyle,
          onPressed: widget.isLoading ? null : _handlePressed,
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
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(widget.label, key: ValueKey(widget.label)),
          ),
        ),
      ),
    );
  }
}
