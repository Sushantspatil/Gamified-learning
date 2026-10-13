import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../widgets/splash_loading_bar.dart';
import '../widgets/splash_particles.dart';

/// The dedicated cinematic SkillVerse splash screen.
///
/// Features:
/// - Full-screen high-res artwork asset (portrait responsive, BoxFit.cover)
/// - Initial smooth fade-in (0 -> 1)
/// - Subtle breathing scale (1.00 -> 1.025)
/// - Ambient magical glowing particles overlay
/// - Soft book/character glow pulse
/// - Animated glowing gradient progress indicator
/// - System UI styling with transparent status bar and dark navy navigation bar
/// - Purely presentational; navigation is driven by RouteGuards once startup resolves.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _splashAssetPath =
      'assets/images/splash/skillverse_splash.png';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _breathingController;
  late final Animation<double> _breathingAnimation;

  late final AnimationController _glowController;
  late final Animation<double> _glowOpacityAnimation;
  late final Animation<double> _glowScaleAnimation;

  late final AnimationController _particleController;

  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  bool _isPrecachingDone = false;

  @override
  void initState() {
    super.initState();

    // 1. Initial fade-in (600 - 900ms)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // 2. Subtle breathing scale (1.00 -> 1.025 over ~3.5s)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );
    _breathingController.repeat(reverse: true);

    // 3. Central book/character glow pulse (~2s repeating)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowOpacityAnimation = Tween<double>(begin: 0.14, end: 0.30).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    _glowScaleAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    _glowController.repeat(reverse: true);

    // 4. Ambient particles controller (3s repeating cycle)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // 5. Visual progress sweep (0.0 -> 1.0 over ~2.1 seconds)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
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
  void dispose() {
    _fadeController.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduceMotion(context);
    final mediaQuery = MediaQuery.sizeOf(context);

    // System overlay: immersive, transparent status bar, dark navy nav bar
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
          opacity: reduceMotion ? const AlwaysStoppedAnimation(1.0) : _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-screen Artwork with subtle breathing scale
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _breathingAnimation,
                  builder: (context, child) {
                    final scale = reduceMotion ? 1.0 : _breathingAnimation.value;
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    _splashAssetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),

              // 2. Central Character / Book Glow Pulse (Alignment: center, slightly below middle)
              if (!reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FractionalTranslation(
                        translation: const Offset(0.0, 0.08),
                        child: AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, _) {
                            final opacity = _glowOpacityAnimation.value;
                            final scale = _glowScaleAnimation.value;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 280,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.gemCyan.withValues(alpha: opacity),
                                      AppColors.primary.withValues(alpha: opacity * 0.5),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
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

              // 3. Ambient Floating Magical Particles
              if (!reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: SplashParticlesOverlay(
                      animation: _particleController,
                    ),
                  ),
                ),

              // 4. Bottom Loading Section (Aligned over the loading region)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: (mediaQuery.height * 0.045).clamp(28.0, 56.0),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated glowing gradient progress indicator
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, _) {
                            final progress = reduceMotion
                                ? 1.0
                                : _progressAnimation.value;
                            return SplashLoadingBar(
                              progress: progress,
                              height: 15.0,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Loading text
                        const Text(
                          'Loading your adventure...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFF6D5DFE),
                                blurRadius: 10,
                              ),
                              Shadow(
                                color: Color(0xFF060814),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
