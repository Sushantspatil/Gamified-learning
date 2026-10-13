import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../widgets/splash_loading_bar.dart';
import '../widgets/splash_particles.dart';

/// The dedicated cinematic SkillVerse splash screen.
///
/// Cross-device engineering:
/// - Frame-driven animations using normalized 0.0 -> 1.0 progress (60/90/120 Hz safe)
/// - Streamlined to <= 3 AnimationControllers for minimal battery & CPU usage
/// - Exact artwork capsule alignment: animates the artwork's existing progress bar
///   without adding duplicate bottom horizontal bars or extra text
/// - Full AppLifecycleState observer handling
/// - Navigation double-trigger protection (_hasNavigated)
/// - Reduced motion accessibility respect
/// - Dark navy baseline (#060814) to prevent white flash
/// - Purely presentational; authoritative routing is driven by RouteGuards.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _splashAssetPath =
      'assets/images/splash/skillverse_splash.png';

  // 1. Initial fade-in & screen exit transition controller
  late final AnimationController _transitionController;
  late final Animation<double> _fadeAnimation;

  // 2. Single consolidated ambient loop controller (drives breathing, glow, particles, shimmer)
  late final AnimationController _ambientLoopController;

  // 3. Visual progress indicator sweep controller (0.0 -> 1.0)
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  bool _isPrecachingDone = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Initial Fade-In (700ms, Curves.easeOut)
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOut,
    );
    _transitionController.forward();

    // 2. Ambient Loop Controller (4200ms repeating cycle)
    _ambientLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    // 3. Visual Progress Controller (2200ms sweep)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );
    _progressController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPrecachingDone) {
      _isPrecachingDone = true;
      precacheImage(const AssetImage(_splashAssetPath), context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_ambientLoopController.isAnimating) {
        _ambientLoopController.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      final reduceMotion = AppMotion.reduceMotion(context);
      if (!reduceMotion && !_ambientLoopController.isAnimating) {
        _ambientLoopController.repeat();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transitionController.dispose();
    _ambientLoopController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  /// Safe navigation hook ensuring transitions occur only once and while mounted.
  void markNavigated() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotion(context);

    if (reduceMotion && _ambientLoopController.isAnimating) {
      _ambientLoopController.stop();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF060814),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF060814),
        body: FadeTransition(
          opacity: reduceMotion
              ? const AlwaysStoppedAnimation(1.0)
              : _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

              // Calculate exact destination size and offset of the 576x1024 artwork on this screen
              final fittedSizes = applyBoxFit(
                BoxFit.cover,
                const Size(576.0, 1024.0),
                screenSize,
              );
              final destinationSize = fittedSizes.destination;
              final double offsetX = (screenSize.width - destinationSize.width) / 2.0;
              final double offsetY = (screenSize.height - destinationSize.height) / 2.0;

              // Artwork capsule exact metrics measured in 576 x 1024 coordinate space:
              // Left: 122.0, Top: 871.0, Width: 331.0, Height: 32.0 (Center Y = 887.0)
              final barLeft = offsetX + destinationSize.width * (122.0 / 576.0);
              final barTop = offsetY + destinationSize.height * (871.0 / 1024.0);
              final barWidth = destinationSize.width * (331.0 / 576.0);
              final barHeight = destinationSize.height * (32.0 / 1024.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Artwork & existing progress bar overlay locked together with cinematic breathing scale
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _ambientLoopController,
                      builder: (context, child) {
                        final t = _ambientLoopController.value;
                        // Smooth sinusoidal breathing between 1.000 and 1.018
                        final scale = reduceMotion
                            ? 1.0
                            : 1.0 +
                                0.018 *
                                    ((math.sin(t * 2 * math.pi - math.pi / 2) + 1) /
                                        2);

                        return Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base splash artwork
                          Image.asset(
                            _splashAssetPath,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.medium,
                          ),

                          // Animated progress bar overlaid directly onto the artwork's existing capsule
                          Positioned(
                            left: barLeft,
                            top: barTop,
                            width: barWidth,
                            height: barHeight,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _progressAnimation,
                                _ambientLoopController,
                              ]),
                              builder: (context, _) {
                                final progress = reduceMotion
                                    ? 1.0
                                    : _progressAnimation.value;
                                final shimmer = reduceMotion
                                    ? 0.0
                                    : (_ambientLoopController.value * 2.5) % 1.0;

                                return SplashLoadingBar(
                                  progress: progress,
                                  shimmerProgress: shimmer,
                                  width: barWidth,
                                  height: barHeight,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Central Character / Book Glow Pulse (1.8 - 2.4s period, opacity 0.10 -> 0.25, scale 0.96 -> 1.04)
                  if (!reduceMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: FractionalTranslation(
                            translation: const Offset(0.0, 0.08),
                            child: AnimatedBuilder(
                              animation: _ambientLoopController,
                              builder: (context, _) {
                                final t = _ambientLoopController.value;
                                // 2 full pulse cycles per 4.2s loop (~2.1s per pulse)
                                final pulseFactor =
                                    ((math.sin(t * 4 * math.pi - math.pi / 2) + 1) /
                                        2);
                                final opacity = 0.10 + 0.15 * pulseFactor;
                                final scale = 0.96 + 0.08 * pulseFactor;

                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 280,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.gemCyan
                                              .withValues(alpha: opacity),
                                          AppColors.violet
                                              .withValues(alpha: opacity * 0.6),
                                          AppColors.coinGold
                                              .withValues(alpha: opacity * 0.25),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.40, 0.65, 1.0],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Ambient Floating Magical Particles & Sparkles
                  if (!reduceMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _ambientLoopController,
                          builder: (context, _) {
                            return SplashParticlesOverlay(
                              animationProgress: _ambientLoopController.value,
                            );
                          },
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
