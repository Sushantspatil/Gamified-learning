import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';

class AnimatedCountText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final TextAlign? textAlign;

  /// Overrides how long the count takes (the default is a quick tick).
  final Duration? duration;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.textAlign,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return Text('$prefix$value$suffix', style: style, textAlign: textAlign);
    }

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration ?? AppMotion.normal,
      curve: AppMotion.easeOut,
      builder: (context, animatedValue, _) {
        return Text(
          '$prefix$animatedValue$suffix',
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
