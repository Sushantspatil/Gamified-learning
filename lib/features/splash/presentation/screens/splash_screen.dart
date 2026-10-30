import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../widgets/splash_loading_bar.dart';
import '../widgets/splash_particles.dart';

/// The dedicated cinematic SkillVerse splash screen.
///
/// Features:
/// - Single animated Flutter loading bar with smooth gradient and glow (no static baked bar)
/// - Clean splash artwork (`skillverse_splash_no_loader.png`) ending after the magical platform
/// - Dedicated bottom loading region with progress bar and 'Loading your adventure...' text
/// - Frame-driven animations using normalized 0.0 -> 1.0 progress (60/90/120 Hz safe)
/// - Consolidated to <= 3 AnimationControllers
/// - AppLifecycleState observer handling
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
      'assets/images/splash/skillverse_splash_no_loader.png';

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

    if (reduceMotion) {
      if (_ambientLoopController.isAnimating) {
        _ambientLoopController.stop();
      }
    } else {
      if (!_ambientLoopController.isAnimating) {
        _ambientLoopController.repeat();
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0D0A2B),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0A2B),
        body: FadeTransition(
          opacity: reduceMotion
              ? const AlwaysStoppedAnimation(1.0)
              : _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double barWidth =
                  (constraints.maxWidth * 0.74).clamp(240.0, 340.0);
              const double barHeight = 20.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Upper Splash Artwork (No baked loader) with ambient breathing animation
                  Positioned.fill(
                    bottom: 110.0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _ambientLoopController,
                        builder: (context, child) {
                          final t = _ambientLoopController.value;
                          final scale = reduceMotion
                              ? 1.0
                              : 1.0 +
                                  0.015 *
                                      ((math.sin(t * 2 * math.pi - math.pi / 2) + 1) /
                                          2);

                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          _splashAssetPath,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),

                  // 2. Central Character / Book Glow Pulse
                  if (!reduceMotion)
                    Positioned.fill(
                      bottom: 110.0,
                      child: IgnorePointer(
                        child: Center(
                          child: FractionalTranslation(
                            translation: const Offset(0.0, 0.05),
                            child: AnimatedBuilder(
                              animation: _ambientLoopController,
                              builder: (context, _) {
                                final t = _ambientLoopController.value;
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

                  // 4. Dedicated Bottom Loading Region: Exactly ONE Animated Progress Bar + Label
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 28.0,
                          left: 24.0,
                          right: 24.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
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
                            const SizedBox(height: 14.0),
                            Text(
                              'Loading your adventure...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                color: const Color(0xFFD2CCFA),
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
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
    );
  }
}
