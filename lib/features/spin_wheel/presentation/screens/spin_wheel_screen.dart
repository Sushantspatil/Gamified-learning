import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_key.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/data/rewards_catalog.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../widgets/spin_wheel_painter.dart';

/// Deep red casino backdrop, as in the reference design. It is part of the
/// wheel's look, so it is the same in light and dark themes.
const Color _screenDark = Color(0xFF2A0306);
const Color _gold = Color(0xFFFFB900);
const Color _onGold = Color(0xFF5A0A00);

class SpinWheelScreen extends ConsumerStatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  /// Extra full turns before settling on the prize (6 plus the final part).
  static const int _extraTurns = 6;
  static const Duration _spinDuration = Duration(milliseconds: 6000);

  late final AnimationController _controller;

  /// Segment 0 rests centred under the pointer, like the reference.
  late double _angle = wheelRestAngle(0, RewardsCatalog.wheel.length);
  late Animation<double> _rotation = AlwaysStoppedAnimation<double>(_angle);
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Left mid-spin earlier: the prize is already decided; show it and pay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(rewardsProvider).pendingSpinReward;
      if (pending == null) return;
      final index = RewardsCatalog.wheel.indexWhere((s) => s.coins == pending);
      _angle = wheelRestAngle(index, RewardsCatalog.wheel.length);
      _rotation = AlwaysStoppedAnimation<double>(_angle);
      _spinning = true;
      _finishSpin();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return; // ignore taps while a spin is running
    _spinning = true; // lock before anything else, so rapid taps are no-ops
    final index = ref.read(rewardsProvider.notifier).startSpin();
    if (index == null) {
      _spinning = false;
      return;
    }

    final count = RewardsCatalog.wheel.length;
    final random = ref.read(rewardsRandomProvider);
    // The stop angle is computed from the chosen segment itself, so the
    // pointer ends inside exactly that segment (never on a neighbour).
    final target = wheelTargetAngle(
      index: index,
      segmentCount: count,
      currentAngle: _angle,
      turns: _extraTurns,
      offsetFraction: (random.nextDouble() - 0.5) * 0.6,
    );
    assert(segmentIndexAtPointer(target, count) == index);

    _controller.duration = AppMotion.reduceMotion(context)
        ? const Duration(milliseconds: 400)
        : _spinDuration;
    _rotation = Tween<double>(
      begin: _angle,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    setState(() {});

    await _controller.forward(from: 0);
    if (!mounted) return; // prize is saved as pending and paid on next open
    _angle = target;
    await _finishSpin();
  }

  Future<void> _finishSpin() async {
    final coins = ref.read(rewardsProvider.notifier).completeSpin();
    if (!mounted) return;
    setState(() => _spinning = false);
    if (coins == null) return;
    await showRewardDialog(
      context,
      title: 'Congratulations!',
      message: 'You won $coins Coins.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final todayKey = dateKey(ref.read(rewardsClockProvider)());
    final canSpin = ref.watch(
      rewardsProvider.select((s) => s.canSpinOn(todayKey)),
    );
    final available = canSpin && !_spinning;

    return Scaffold(
      backgroundColor: _screenDark,
      appBar: AppBar(
        backgroundColor: _screenDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Spin the Wheel'),
        actions: const [
          CoinBalanceChip(),
          SizedBox(width: AppSpacing.xs),
          ThemeModeMenu(),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF9B1A10), Color(0xFF5A0A0C), _screenDark],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: AppSpacing.paddingMd,
                children: [
                  // The wheel comes first: its glow and rays spill past its
                  // box, and everything after it is painted on top of them.
                  _WheelStage(rotation: _rotation, spinning: _spinning),
                  const SizedBox(height: AppSpacing.lg),
                  _SpinButton(
                    label: _spinning ? 'Spinning…' : 'Spin Now',
                    onPressed: available ? _spin : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    !canSpin && !_spinning
                        ? "You've already spun today. Come back tomorrow!"
                        : 'Spin once a day to win coins.',
                    key: !canSpin && !_spinning
                        ? const Key('already_spun')
                        : null,
                    textAlign: TextAlign.center,
                    style: styles.bodyLarge.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SpinButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.casino_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _onGold,
          disabledBackgroundColor: const Color(0xFF6B4A12),
          disabledForegroundColor: const Color(0xFFD9B766),
          textStyle: context.appTextStyles.button.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Layers, back to front: glow and rays, the spinning face, the fixed metal
/// ring and hub, the blinking bulbs, and the pointer. Only the face rotates;
/// the rest stay put, like a real prize wheel.
class _WheelStage extends StatefulWidget {
  final Animation<double> rotation;
  final bool spinning;

  const _WheelStage({required this.rotation, required this.spinning});

  @override
  State<_WheelStage> createState() => _WheelStageState();
}

class _WheelStageState extends State<_WheelStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _twinkle.stop();
      _twinkle.value = 0.5;
    } else if (!_twinkle.isAnimating) {
      // Bounded (about a minute) so an unattended screen stops animating.
      _twinkle.repeat(reverse: true, count: 90);
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final labelStyle = context.appTextStyles.headingLarge;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math
            .min(constraints.maxWidth - 24, math.min(360.0, screenHeight * 0.5))
            .clamp(220.0, 360.0);

        Widget layer(Widget child) => Positioned.fill(child: child);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  layer(
                    const RepaintBoundary(
                      child: CustomPaint(painter: WheelBackdropPainter()),
                    ),
                  ),
                  layer(
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: widget.rotation,
                        builder: (context, child) => Transform.rotate(
                          angle: widget.rotation.value,
                          child: child,
                        ),
                        child: CustomPaint(
                          painter: SpinWheelPainter(
                            segments: RewardsCatalog.wheel,
                            labelStyle: labelStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  layer(
                    const RepaintBoundary(
                      child: CustomPaint(painter: WheelRingPainter()),
                    ),
                  ),
                  layer(
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: WheelBulbsPainter(phase: _twinkle),
                      ),
                    ),
                  ),
                  layer(
                    const RepaintBoundary(
                      child: CustomPaint(painter: WheelPointerPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
