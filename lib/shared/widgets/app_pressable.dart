import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/motion/app_motion.dart';

class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool enableHaptics;
  final double pressedScale;

  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.enableHaptics = true,
    this.pressedScale = 0.985,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed || widget.onTap == null) return;
    setState(() => _isPressed = isPressed);
  }

  void _handleTap() {
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotion(context);
    final scale = _isPressed && !reduceMotion ? widget.pressedScale : 1.0;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.duration(context, AppMotion.instant),
        curve: AppMotion.easeOut,
        child: InkWell(
          onTap: widget.onTap == null ? null : _handleTap,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
