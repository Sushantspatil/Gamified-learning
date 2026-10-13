import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// A custom glowing progress bar designed to align with the SkillVerse
/// fantasy neon aesthetic.
class SplashLoadingBar extends StatelessWidget {
  final double progress;
  final double? width;
  final double height;

  const SplashLoadingBar({
    super.key,
    required this.progress,
    this.width,
    this.height = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final barWidth = width ?? (screenWidth * 0.66).clamp(220.0, 320.0);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final borderRadius = BorderRadius.circular(height / 2);

    return Container(
      width: barWidth,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF090D24).withValues(alpha: 0.85),
        borderRadius: borderRadius,
        border: Border.all(
          color: const Color(0xFF6D5DFE).withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D5DFE).withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF21E6FF).withValues(alpha: 0.20),
            blurRadius: 6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular((height - 4) / 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * clampedProgress;
              return Stack(
                children: [
                  // Gradient fill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.gemCyan, // #21E6FF
                            AppColors.primary, // #6D5DFE
                            AppColors.violet,  // #B052FF
                            Color(0xFFE548FF), // pink highlight
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gemCyan.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Leading tip glow
                  if (clampedProgress > 0.05)
                    Positioned(
                      left: (fillWidth - 8).clamp(0.0, constraints.maxWidth),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.85),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gemCyan,
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
