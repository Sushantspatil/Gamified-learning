import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_key.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/data/rewards_catalog.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../widgets/spin_wheel_painter.dart';

class SpinWheelScreen extends ConsumerStatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  static const int _extraTurns = 5;

  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);
  double _angle = 0;
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
      _angle = wheelTargetAngle(
        index: index,
        segmentCount: RewardsCatalog.wheel.length,
        currentAngle: 0,
        turns: 0,
      );
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
        : const Duration(milliseconds: 4500);
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
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final todayKey = dateKey(ref.read(rewardsClockProvider)());
    final canSpin = ref.watch(
      rewardsProvider.select((s) => s.canSpinOn(todayKey)),
    );
    final available = canSpin && !_spinning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin the Wheel'),
        actions: const [
          CoinBalanceChip(),
          SizedBox(width: AppSpacing.xs),
          ThemeModeMenu(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(
                  'Spin once a day to win coins.',
                  textAlign: TextAlign.center,
                  style: styles.bodyLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                _WheelStage(rotation: _rotation),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _spinning ? 'Spinning…' : 'Spin Now',
                  leadingIcon: const Icon(Icons.casino_rounded),
                  onPressed: available ? _spin : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!canSpin && !_spinning)
                  Text(
                    "You've already spun today. Come back tomorrow!",
                    key: const Key('already_spun'),
                    textAlign: TextAlign.center,
                    style: styles.bodyLarge,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelStage extends StatelessWidget {
  final Animation<double> rotation;

  const _WheelStage({required this.rotation});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelSize = math
            .min(constraints.maxWidth - 16, math.min(320.0, screenHeight * 0.5))
            .clamp(180.0, 320.0);
        final pointerWidth = wheelSize * 0.12;
        final pointerHeight = pointerWidth * 1.2;

        return Center(
          child: SizedBox(
            width: wheelSize,
            height: wheelSize + pointerHeight * 0.6,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: pointerHeight * 0.6,
                  child: SizedBox(
                    width: wheelSize,
                    height: wheelSize,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: rotation,
                        builder: (context, child) => Transform.rotate(
                          angle: rotation.value,
                          child: child,
                        ),
                        child: CustomPaint(
                          size: Size.square(wheelSize),
                          painter: SpinWheelPainter(
                            segments: RewardsCatalog.wheel,
                            rimColor: colors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: pointerHeight * 0.6 + wheelSize / 2 - wheelSize * 0.07,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: SizedBox.square(dimension: wheelSize * 0.14),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: SizedBox(
                    width: pointerWidth,
                    height: pointerHeight,
                    child: CustomPaint(
                      painter: WheelPointerPainter(color: colors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
