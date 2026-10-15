import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// A custom glowing progress bar designed to align precisely with the SkillVerse
/// splash artwork's existing capsule loading bar.
///
/// Features:
/// - Exact capsule geometry fitting the artwork's outer frame
/// - High-contrast dark track background (#0C1344) covering the static 60% fill in the PNG
/// - Fluid cyan -> blue -> violet -> pink gradient progress fill
/// - Traveling shimmer highlight beam across the active progress fill
/// - Bright glowing leading tip head (white core + cyan radial bloom)
/// - Completely frame-rate agnostic (driven by normalized animation progress)
/// - RepaintBoundary isolation to avoid repainting parent trees
/// - Semantics accessibility support
class SplashLoadingBar extends StatelessWidget {
  final double progress;
  final double shimmerProgress;
  final double? width;
  final double height;

  const SplashLoadingBar({
    super.key,
    required this.progress,
    this.shimmerProgress = 0.0,
    this.width,
    this.height = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final borderRadius = BorderRadius.circular(height / 2);
    final borderWidth = (height * 0.05).clamp(1.0, 1.8);
    final innerPadding = (height * 0.12).clamp(1.5, 3.5);

    return Semantics(
      label: 'Loading your adventure',
      value: '${(clampedProgress * 100).toInt()}%',
      child: RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF0C1344).withValues(alpha: 0.94),
            borderRadius: borderRadius,
            border: Border.all(
              color: const Color(0xFF21E6FF).withValues(alpha: 0.85),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF21E6FF).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
              BoxShadow(
                color: const Color(0xFFB052FF).withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(innerPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((height - innerPadding * 2) / 2),
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

                      // Traveling shimmer highlight over the filled portion
                      if (clampedProgress > 0.06)
                        Positioned(
                          left: ((shimmerProgress % 1.0) * fillWidth * 1.25) - 35.0,
                          top: 0,
                          bottom: 0,
                          width: (fillWidth * 0.35).clamp(24.0, 50.0),
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.50),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Subtle soft glow at leading edge (no hard white slider thumb)
                      if (clampedProgress > 0.02)
                        Positioned(
                          left: (fillWidth - 8.0).clamp(0.0, constraints.maxWidth - 16.0),
                          top: 0,
                          bottom: 0,
                          width: 16.0,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.70),
                                    const Color(0xFF21E6FF).withValues(alpha: 0.40),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
