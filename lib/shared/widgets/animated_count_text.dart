import 'package:flutter/material.dart';

import '../../app/motion/app_motion.dart';

class AnimatedCountText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  final TextAlign? textAlign;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return Text('$value$suffix', style: style, textAlign: textAlign);
    }

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: AppMotion.normal,
      curve: AppMotion.easeOut,
      builder: (context, animatedValue, _) {
        return Text(
          '$animatedValue$suffix',
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
