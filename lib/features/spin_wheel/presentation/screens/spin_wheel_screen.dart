import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../rewards_hub/data/rewards_mock_data.dart';
import '../../../rewards_hub/domain/rewards_models.dart';
import '../../../rewards_hub/presentation/providers/rewards_providers.dart';
import '../../../rewards_hub/presentation/widgets/rewards_common_widgets.dart';
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
    // If the screen was left mid-spin, the prize is already decided: show
    // the wheel on it and finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(rewardsProvider).pendingSpinSegmentId;
      if (pending == null) return;
      final index = RewardsMockData.wheelSegments.indexWhere(
        (s) => s.id == pending,
      );
      _angle = wheelTargetAngle(
        index: index,
        segmentCount: RewardsMockData.wheelSegments.length,
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
    if (_spinning) return;
    final notifier = ref.read(rewardsProvider.notifier);
    final index = notifier.startSpin();
    if (index == null) return;

    final segmentCount = RewardsMockData.wheelSegments.length;
    final random = ref.read(rewardsRandomProvider);
    final target = wheelTargetAngle(
      index: index,
      segmentCount: segmentCount,
      currentAngle: _angle,
      turns: _extraTurns,
      offsetFraction: (random.nextDouble() - 0.5) * 0.6,
    );
    assert(segmentIndexAtPointer(target, segmentCount) == index);

    final reduceMotion = AppMotion.reduceMotion(context);
    _controller.duration = reduceMotion
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 5200);
    _rotation = Tween<double>(
      begin: _angle,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    setState(() => _spinning = true);
    ref.read(gameAudioServiceProvider).play(GameSound.powerUp);

    await _controller.forward(from: 0);
    if (!mounted) return;
    _angle = target;
    await _finishSpin();
  }

  Future<void> _finishSpin() async {
    final reward = ref.read(rewardsProvider.notifier).completeSpin();
    if (!mounted) return;
    setState(() => _spinning = false);
    if (reward == null) return;

    ref
        .read(gameAudioServiceProvider)
        .play(
          reward.kind == RewardKind.xp
              ? GameSound.xpReward
              : GameSound.coinReward,
        );
    await showRewardPopup(
      context,
      heading: 'You won ${_rewardName(reward)}!',
      subtitle: 'Added to your rewards.',
      rewards: [reward],
    );
  }

  String _rewardName(RewardItem reward) => switch (reward.kind) {
    RewardKind.coins => '${reward.amount} Coins',
    RewardKind.xp => '${reward.amount} Bonus XP',
    _ => reward.title,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final now = ref.read(rewardsClockProvider)();
    final canSpin = ref.watch(
      rewardsProvider.select((s) => s.isSpinAvailableOn(now)),
    );
    // Re-evaluated when the spin gets used or the day rolls over.
    final available = canSpin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Rewards'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: AppSpacing.sm,
                  children: [
                    const CoinBalanceChip(),
                    AppBadge(
                      label: _spinning
                          ? 'Spinning'
                          : available
                          ? '1 free spin'
                          : 'Spin used',
                      variant: available
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Spin the wheel for a daily prize.',
                  textAlign: TextAlign.center,
                  style: styles.bodyLarge.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                _WheelStage(rotation: _rotation),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _spinning
                      ? 'Spinning…'
                      : available
                      ? 'Spin Now'
                      : 'Spin used today',
                  leadingIcon: Icon(
                    _spinning
                        ? Icons.hourglass_top_rounded
                        : Icons.casino_rounded,
                  ),
                  onPressed: available && !_spinning ? _spin : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!available && !_spinning)
                  _NextSpinCountdown(
                    onElapsed: () {
                      if (mounted) setState(() {});
                    },
                  )
                else
                  Text(
                    'Tap Spin Now to try your luck. You get one free spin '
                    'every day, and the prize lands on whichever segment '
                    'the pointer stops at.',
                    textAlign: TextAlign.center,
                    style: styles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Previous rewards', style: styles.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                const _SpinHistoryList(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Demo mode: rewards are stored on this device only.',
                  textAlign: TextAlign.center,
                  style: styles.caption.copyWith(color: colors.textMuted),
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
            .min(constraints.maxWidth - 16, math.min(340.0, screenHeight * 0.5))
            .clamp(200.0, 340.0);
        final pointerWidth = wheelSize * 0.12;
        final pointerHeight = pointerWidth * 1.25;

        return Center(
          child: SizedBox(
            width: wheelSize,
            height: wheelSize + pointerHeight * 0.55,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: pointerHeight * 0.55,
                  child: SizedBox(
                    width: wheelSize,
                    height: wheelSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
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
                              segments: RewardsMockData.wheelSegments,
                              rimColor: colors.primaryDark,
                              rimHighlight: const Color(0xFFFFE08A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: pointerHeight * 0.55 + wheelSize / 2 - wheelSize * 0.09,
                  child: _WheelHub(size: wheelSize * 0.18),
                ),
                Positioned(
                  top: 0,
                  child: SizedBox(
                    width: pointerWidth,
                    height: pointerHeight,
                    child: CustomPaint(
                      painter: WheelPointerPainter(
                        color: colors.error,
                        outline: Colors.white,
                      ),
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

class _WheelHub extends StatelessWidget {
  final double size;

  const _WheelHub({required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryDark],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.star_rounded, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

/// Ticks once a second on its own; the rest of the screen does not rebuild.
class _NextSpinCountdown extends ConsumerStatefulWidget {
  final VoidCallback onElapsed;

  const _NextSpinCountdown({required this.onElapsed});

  @override
  ConsumerState<_NextSpinCountdown> createState() => _NextSpinCountdownState();
}

class _NextSpinCountdownState extends ConsumerState<_NextSpinCountdown> {
  Timer? _timer;
  late Duration _remaining;

  Duration _computeRemaining() {
    final now = ref.read(rewardsClockProvider)();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _computeRemaining();
      if (remaining <= Duration.zero) {
        _timer?.cancel();
        widget.onElapsed();
        return;
      }
      setState(() => _remaining = remaining);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    return Column(
      children: [
        Text(
          'Next free spin in',
          style: styles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _format(_remaining),
          key: const Key('spin_countdown'),
          style: styles.headingSmall.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SpinHistoryList extends ConsumerWidget {
  const _SpinHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rewardsProvider.select((s) => s.spinHistory));
    final now = ref.read(rewardsClockProvider)();
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final entries = history.take(5).toList();

    if (entries.isEmpty) {
      return AppCard(
        child: Text(
          'No spins yet.',
          style: styles.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppDimensions.radiusMd,
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.ms,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    RewardIconBadge(
                      icon: entry.icon,
                      color: entry.color,
                      size: 36,
                    ),
                    const SizedBox(width: AppSpacing.ms),
                    Expanded(
                      child: Text(
                        entry.title,
                        style: styles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _whenLabel(entry.at, now),
                      style: styles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _whenLabel(DateTime at, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }
}
