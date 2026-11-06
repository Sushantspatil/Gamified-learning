import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/motion/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_key.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../character3d/presentation/character_3d_view.dart';
import '../../../character3d/presentation/character_glow.dart';
import '../../../character3d/presentation/equipped_cosmetics.dart';
import '../../../rewards/application/rewards_controller.dart';
import '../../../rewards/data/rewards_catalog.dart';
import '../../../rewards/presentation/widgets/coin_balance_chip.dart';
import '../widgets/spin_wheel_effects.dart';
import '../widgets/spin_wheel_motion.dart';
import '../widgets/spin_wheel_painter.dart';
import '../widgets/wheel_win_dialog.dart';

const Color _gold = Color(0xFFFFB900);
const Color _onGold = Color(0xFF5A0A00);

/// The colours around the wheel: a night-time casino red in dark mode and a
/// bright, sunny gold in light mode. The wheel itself looks the same in both.
class _Look {
  final bool light;

  const _Look(this.light);

  /// Centre, middle and edge of the background.
  List<Color> get gradient => light
      ? const [Color(0xFFFFF4D2), Color(0xFFFFC46B), Color(0xFFF28A3A)]
      : const [Color(0xFF9B1A10), Color(0xFF5A0A0C), Color(0xFF2A0306)];

  Color get edge => gradient.last;

  /// What the centre brightens towards while the wheel spins.
  Color get surge => light ? const Color(0xFFFFFFFF) : const Color(0xFFD2481A);

  Color get title => light ? const Color(0xFF5A1A00) : Colors.white;
  Color get caption => light ? const Color(0xFF6B2A00) : Colors.white70;

  Color get buttonBg => light ? const Color(0xFFB90000) : _gold;
  Color get buttonFg => light ? Colors.white : _onGold;
  Color get buttonOffBg =>
      light ? const Color(0xFFE2B785) : const Color(0xFF6B4A12);
  Color get buttonOffFg =>
      light ? const Color(0xFF8A5A2A) : const Color(0xFFD9B766);
  Color get buttonGlow => light ? const Color(0xFFB90000) : _gold;
}

class SpinWheelScreen extends ConsumerStatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen>
    with TickerProviderStateMixin {
  /// Extra full turns before settling on the prize (6 plus the final part).
  static const int _extraTurns = 6;
  static const Duration _spinDuration = Duration(milliseconds: 6400);

  /// While a spin is available the wheel drifts a little, so it never looks
  /// like a still picture. It is bounded, so an unattended screen goes quiet.
  static const Duration _driftDuration = Duration(seconds: 90);
  static const double _driftAngle = 1.0;

  late final AnimationController _controller = AnimationController(vsync: this);
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: _driftDuration,
  );
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  final Character3dController _character = Character3dController();

  /// Loops (a bounded number of times) to move the background: turning rays,
  /// a breathing glow and drifting sparkles.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  /// 0 when idle, 1 while the wheel spins: the background gets livelier.
  late final AnimationController _energy = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  SparkleFieldPainter? _sparkles;
  bool? _sparklesLight;

  /// Built once: a new theme on every refresh would keep restarting the
  /// character glow's animation.
  late final ThemeData _darkTheme = AppTheme.darkTheme;

  final GlobalKey _bodyKey = GlobalKey();
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _chipKey = GlobalKey();

  Timer? _clock;

  /// Segment 0 rests centred under the pointer, like the reference.
  late double _angle = wheelRestAngle(0, RewardsCatalog.wheel.length);
  late Animation<double> _rotation = AlwaysStoppedAnimation<double>(_angle);
  bool _spinning = false;

  /// True while the "You won" popup is open: the character on this screen
  /// steps aside, because the popup has its own.
  bool _winDialogOpen = false;

  /// The prize that just won, while it flashes and the coins fly.
  int? _winIndex;
  Offset? _burstFrom;
  Offset? _burstTo;

  @override
  void initState() {
    super.initState();
    // The "next spin in ..." label counts down.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Left mid-spin earlier: the prize is already decided; show it and pay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(rewardsProvider).pendingSpinReward;
      if (pending == null) {
        _startDrift();
        return;
      }
      final index = RewardsCatalog.wheel.indexWhere((s) => s.coins == pending);
      _angle = wheelRestAngle(index, RewardsCatalog.wheel.length);
      _rotation = AlwaysStoppedAnimation<double>(_angle);
      _spinning = true;
      _finishSpin();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _controller.dispose();
    _idle.dispose();
    _win.dispose();
    _ambient.dispose();
    _energy.dispose();
    _character.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _ambient.stop();
      _ambient.value = 0.3;
    } else if (!_ambient.isAnimating && _ambient.value < 1) {
      // Bounded (two minutes), so an unattended screen goes quiet.
      _ambient.repeat(count: 4);
    }
  }

  DateTime get _now => ref.read(rewardsClockProvider)();

  void _startDrift() {
    if (!mounted || _spinning || AppMotion.reduceMotion(context)) return;
    if (!ref.read(rewardsProvider).canSpinOn(dateKey(_now))) return;
    setState(() {
      _rotation = Tween<double>(
        begin: _angle,
        end: _angle + _driftAngle,
      ).animate(_idle);
    });
    _idle.forward(from: 0);
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
    // Start from wherever the idle drift has taken the wheel.
    final from = _rotation.value;
    _idle.stop();
    _angle = from;
    // The stop angle is computed from the chosen segment itself, so the
    // pointer ends inside exactly that segment (never on a neighbour).
    final target = wheelTargetAngle(
      index: index,
      segmentCount: count,
      currentAngle: from,
      turns: _extraTurns,
      offsetFraction: (random.nextDouble() - 0.5) * 0.6,
    );
    assert(segmentIndexAtPointer(target, count) == index);

    final reduce = AppMotion.reduceMotion(context);
    _controller.duration = reduce
        ? const Duration(milliseconds: 400)
        : _spinDuration;
    _rotation = reduce
        ? Tween<double>(
            begin: from,
            end: target,
          ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut))
        : WheelSpinAnimatable(begin: from, end: target).animate(_controller);
    setState(() {});
    // The character waits with its hand on its chin.
    _character.play(Character3dAction.think);
    _energy.animateTo(1);

    await _controller.forward(from: 0);
    if (!mounted) return; // prize is saved as pending and paid on next open
    _angle = target;
    setState(() => _rotation = AlwaysStoppedAnimation<double>(target));
    await _celebrate(index);
    if (!mounted) return;
    await _finishSpin();
  }

  /// The wheel has stopped: the winning prize flashes, the bulbs flash, the
  /// character cheers and coins fly up to the balance. Skipped when the
  /// player prefers reduced motion.
  Future<void> _celebrate(int index) async {
    _character.play(Character3dAction.cheer);
    _character.sparkle();
    if (AppMotion.reduceMotion(context)) return;

    final body = _bodyKey.currentContext?.findRenderObject();
    final stage = _stageKey.currentContext?.findRenderObject();
    final chip = _chipKey.currentContext?.findRenderObject();
    if (body is! RenderBox || stage is! RenderBox || chip is! RenderBox) {
      return;
    }
    Offset centreOf(RenderBox box) =>
        body.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
    setState(() {
      _winIndex = index;
      _burstFrom = centreOf(stage);
      _burstTo = centreOf(chip);
    });
    await _win.forward(from: 0);
    if (!mounted) return;
    setState(() => _winIndex = null);
  }

  Future<void> _finishSpin() async {
    final coins = ref.read(rewardsProvider.notifier).completeSpin();
    if (!mounted) return;
    setState(() => _spinning = false);
    _energy.animateTo(0, duration: const Duration(milliseconds: 1200));
    if (coins == null) return;
    setState(() => _winDialogOpen = true);
    await showWheelWinDialog(
      context,
      coins: coins,
      light: Theme.of(context).brightness == Brightness.light,
      cosmetics: equippedCosmetics(context),
    );
    if (mounted) setState(() => _winDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final now = _now;
    final todayKey = dateKey(now);
    final canSpin = ref.watch(
      rewardsProvider.select((s) => s.canSpinOn(todayKey)),
    );
    final available = canSpin && !_spinning;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final label = _spinning
        ? 'Spinning…'
        : canSpin
        ? 'Spin Now'
        : nextSpinLabel(tomorrow.difference(now));

    final light = Theme.of(context).brightness == Brightness.light;
    final look = _Look(light);
    if (_sparkles == null || _sparklesLight != light) {
      _sparkles = SparkleFieldPainter(
        phase: _ambient,
        energy: _energy,
        light: light,
      );
      _sparklesLight = light;
    }

    return Scaffold(
      backgroundColor: look.edge,
      // The moving background runs under the (transparent) app bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: look.title,
        // The app bar theme sets its own title and icon colours; this screen
        // has its own backdrop, so say so explicitly.
        titleTextStyle: styles.titleLarge.copyWith(color: look.title),
        iconTheme: IconThemeData(color: look.title),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Spin the Wheel'),
        actions: [
          KeyedSubtree(key: _chipKey, child: const CoinBalanceChip()),
          const SizedBox(width: AppSpacing.xs),
          const ThemeModeMenu(),
        ],
      ),
      body: Stack(
        key: _bodyKey,
        children: [
          Positioned.fill(
            child: _LivingBackground(
              ambient: _ambient,
              energy: _energy,
              look: look,
              sparkles: _sparkles!,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final characterHeight = _characterHeight(constraints);
                      return ListView(
                        padding: AppSpacing.paddingMd,
                        children: [
                          // The wheel comes first: its glow and rays spill
                          // past its box, and everything after it is
                          // painted on top of them.
                          KeyedSubtree(
                            key: _stageKey,
                            child: _WheelStage(
                              rotation: _rotation,
                              spinning: _spinning,
                              winIndex: _winIndex,
                              winProgress: _win,
                              restAngle: _angle,
                              ambient: _ambient,
                              energy: _energy,
                              light: light,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SpinButton(
                            label: label,
                            icon: !canSpin && !_spinning
                                ? Icons.schedule_rounded
                                : Icons.casino_rounded,
                            pulse: available,
                            look: look,
                            onPressed: available ? _spin : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            !canSpin && !_spinning
                                ? "You've already spun today."
                                : 'Spin once a day to win coins.',
                            key: !canSpin && !_spinning
                                ? const Key('already_spun')
                                : null,
                            textAlign: TextAlign.center,
                            style: styles.bodyLarge.copyWith(
                              color: look.caption,
                            ),
                          ),
                          if (characterHeight != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _characterSlot(characterHeight),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_winIndex != null && _burstFrom != null && _burstTo != null)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CoinBurstPainter(
                      progress: _win,
                      from: _burstFrom!,
                      to: _burstTo!,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Height for the character under the wheel, or null when the screen is too
  /// short for it (the wheel and the button always come first).
  double? _characterHeight(BoxConstraints constraints) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final width = math.min(520.0, constraints.maxWidth) - AppSpacing.md * 2;
    final wheel = math
        .min(width - 24, math.min(360.0, screenHeight * 0.5))
        .clamp(220.0, 360.0);
    final used =
        wheel +
        AppSpacing.md * 2 + // around the wheel
        AppSpacing.lg +
        52 + // button
        AppSpacing.sm +
        52 + // caption
        AppSpacing.md * 2 + // list padding
        AppSpacing.md; // gap above the character
    final free = constraints.maxHeight - used;
    if (free < 120) return null;
    return math.min(free, 240.0);
  }

  Widget _characterSlot(double height) {
    return AnimatedOpacity(
      key: const Key('spin_character_slot'),
      opacity: _winDialogOpen ? 0 : 1,
      duration: const Duration(milliseconds: 180),
      child: SizedBox(
        height: height,
        child: Center(
          // The screen is dark red in both themes, so light the character as
          // for a dark card.
          child: Theme(
            data: _darkTheme,
            child: CharacterGlow(
              color: _gold,
              child: Character3dView(
                key: const Key('spin_character'),
                width: height * 0.85,
                height: height,
                state: Character3dState.idle,
                controller: _character,
                cosmetics: equippedCosmetics(context),
                ambient: true,
                initialAction: Character3dAction.wave,
                placeholder: const SizedBox.shrink(),
                arrive: true,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The main button. While a spin is available it breathes (a gentle pulse and
/// glow) so it draws the eye; otherwise it just sits there, disabled.
class _SpinButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool pulse;
  final _Look look;
  final VoidCallback? onPressed;

  const _SpinButton({
    required this.label,
    required this.icon,
    required this.pulse,
    required this.look,
    required this.onPressed,
  });

  @override
  State<_SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<_SpinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _SpinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _sync();
  }

  void _sync() {
    if (widget.pulse && !AppMotion.reduceMotion(context)) {
      // Bounded, so an unattended screen settles.
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true, count: 40);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1 + 0.025 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (_pulse.value > 0)
                  BoxShadow(
                    color: widget.look.buttonGlow.withValues(alpha: 0.45 * t),
                    blurRadius: 22 * t,
                    spreadRadius: 1.5 * t,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon),
          label: Text(widget.label),
          style: FilledButton.styleFrom(
            backgroundColor: widget.look.buttonBg,
            foregroundColor: widget.look.buttonFg,
            disabledBackgroundColor: widget.look.buttonOffBg,
            disabledForegroundColor: widget.look.buttonOffFg,
            textStyle: context.appTextStyles.button.copyWith(
              fontWeight: FontWeight.w900,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layers, back to front: glow and rays, the spinning face, a glassy sheen and
/// speed streaks, the winning flash, the fixed metal ring and hub, the bulbs,
/// and the flexing pointer. Only the face rotates; the rest stay put, like a
/// real prize wheel.
class _WheelStage extends StatefulWidget {
  final Animation<double> rotation;
  final bool spinning;

  /// The prize that just won (flashing), the animation that drives the flash,
  /// and the angle the wheel stopped at.
  final int? winIndex;
  final Animation<double> winProgress;
  final double restAngle;

  /// The moving background behind the wheel, and which look it has.
  final Animation<double> ambient;
  final Animation<double> energy;
  final bool light;

  const _WheelStage({
    required this.rotation,
    required this.spinning,
    required this.winIndex,
    required this.winProgress,
    required this.restAngle,
    required this.ambient,
    required this.energy,
    required this.light,
  });

  @override
  State<_WheelStage> createState() => _WheelStageState();
}

class _WheelStageState extends State<_WheelStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  /// One instance for its whole life: it remembers how far the rays have
  /// turned, so rebuilding the screen never makes them jump.
  late WheelBackdropPainter _backdrop = WheelBackdropPainter(
    phase: widget.ambient,
    energy: widget.energy,
    light: widget.light,
  );

  WheelBulbMode get _mode => widget.winIndex != null
      ? WheelBulbMode.flash
      : widget.spinning
      ? WheelBulbMode.chase
      : WheelBulbMode.twinkle;

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
    _retune();
  }

  @override
  void didUpdateWidget(covariant _WheelStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.light != widget.light) {
      _backdrop = WheelBackdropPainter(
        phase: widget.ambient,
        energy: widget.energy,
        light: widget.light,
      );
    }
    final oldMode = oldWidget.winIndex != null
        ? WheelBulbMode.flash
        : oldWidget.spinning
        ? WheelBulbMode.chase
        : WheelBulbMode.twinkle;
    if (oldMode != _mode) _retune();
  }

  /// All of these are bounded, so an unattended screen stops animating.
  void _retune() {
    if (AppMotion.reduceMotion(context)) {
      _twinkle.stop();
      _twinkle.value = 0.5;
      return;
    }
    switch (_mode) {
      case WheelBulbMode.twinkle:
        _twinkle.duration = const Duration(milliseconds: 700);
        _twinkle.repeat(reverse: true, count: 90);
      case WheelBulbMode.chase:
        _twinkle.duration = const Duration(milliseconds: 900);
        _twinkle.repeat(count: 14);
      case WheelBulbMode.flash:
        _twinkle.duration = const Duration(milliseconds: 240);
        _twinkle.repeat(reverse: true, count: 8);
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
    final count = RewardsCatalog.wheel.length;

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
                    RepaintBoundary(child: CustomPaint(painter: _backdrop)),
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
                      child: CustomPaint(painter: WheelGlossPainter()),
                    ),
                  ),
                  layer(
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: WheelSpeedBlurPainter(
                          rotation: widget.rotation,
                          segmentCount: count,
                        ),
                      ),
                    ),
                  ),
                  if (widget.winIndex != null)
                    layer(
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: WheelWinFlashPainter(
                            progress: widget.winProgress,
                            angle: widget.restAngle,
                            index: widget.winIndex!,
                            segmentCount: count,
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
                        painter: WheelBulbsPainter(
                          phase: _twinkle,
                          mode: _mode,
                        ),
                      ),
                    ),
                  ),
                  layer(
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: WheelPointerPainter(
                          rotation: widget.rotation,
                          segmentCount: count,
                        ),
                      ),
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

/// The screen's backdrop: a gradient that sways and brightens while the wheel
/// spins, with sparkles drifting up through it.
class _LivingBackground extends StatelessWidget {
  final Animation<double> ambient;
  final Animation<double> energy;
  final _Look look;
  final CustomPainter sparkles;

  const _LivingBackground({
    required this.ambient,
    required this.energy,
    required this.look,
    required this.sparkles,
  });

  @override
  Widget build(BuildContext context) {
    const tau = 2 * math.pi;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([ambient, energy]),
          builder: (context, _) {
            final p = ambient.value;
            final e = energy.value;
            final g = look.gradient;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.06 * math.sin(tau * p),
                    -0.35 + 0.04 * math.cos(tau * p),
                  ),
                  radius: 1.1 + 0.04 * math.sin(2 * tau * p) + 0.08 * e,
                  colors: [Color.lerp(g[0], look.surge, e * 0.5)!, g[1], g[2]],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            );
          },
        ),
        IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: sparkles)),
        ),
      ],
    );
  }
}
