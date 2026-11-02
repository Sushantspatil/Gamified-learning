import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'character_motion.dart';
import '../application/character_controller.dart';
import '../domain/character_state.dart';
import 'character_assets.dart';
import 'character_pose.dart';

/// Pure presentation of the host character: reads [controller], draws the
/// matching pose. No game logic. [size] is the character's height.
class CharacterView extends StatefulWidget {
  final CharacterController controller;
  final double size;

  /// True while the stage is walking the character: calm poses stop swaying
  /// so they do not fight the walk cycle.
  final bool walking;

  const CharacterView({
    super.key,
    required this.controller,
    required this.size,
    this.walking = false,
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _anim;
  late Listenable _changes;
  StreamSubscription<String?>? _speechSub;
  Timer? _blinkTimer;
  Timer? _mouthTimer;
  Timer? _unblinkTimer;
  final math.Random _random = math.Random();

  bool _layered = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;
  bool _inBackground = false;

  CharacterState get _state => widget.controller.state.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim = AnimationController(vsync: this);
    _changes = Listenable.merge([
      widget.controller.state,
      widget.controller.pulse,
    ]);
    _changes.addListener(_onControllerChanged);
    _speechSub = widget.controller.speech.listen(_onSpeech);
    CharacterAssets.layersAvailable().then((available) {
      if (mounted && available) {
        setState(() => _layered = true);
        _scheduleBlink();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartAnimation();
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _changes.removeListener(_onControllerChanged);
      _speechSub?.cancel();
      _changes = Listenable.merge([
        widget.controller.state,
        widget.controller.pulse,
      ]);
      _changes.addListener(_onControllerChanged);
      _speechSub = widget.controller.speech.listen(_onSpeech);
      _restartAnimation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Nothing runs while backgrounded; the state machine keeps its own state.
    final away =
        lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive ||
        lifecycle == AppLifecycleState.hidden;
    if (away == _inBackground) return;
    _inBackground = away;
    if (away) {
      _anim.stop();
      _blinkTimer?.cancel();
      _mouthTimer?.cancel();
    } else {
      _restartAnimation();
      _scheduleBlink();
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _restartAnimation();
  }

  /// (Re)starts the animation for the controller's current state. Looping
  /// states are bounded so an unattended screen eventually stops ticking.
  void _restartAnimation() {
    if (!mounted || _inBackground) return;
    final state = _state;
    if (CharacterMotion.reduce(context)) {
      _anim.stop();
      _anim.value = 0;
      setState(() {});
      return;
    }
    _anim.duration = poseDuration(
      state,
      intensity: widget.controller.intensity.value,
    );
    if (isLoopingState(state)) {
      _anim.value = 0;
      _anim.repeat(
        reverse: true,
        count: state == CharacterState.win ? 120 : 24,
      );
    } else {
      _anim.forward(from: 0);
    }
    setState(() {});
  }

  void _onSpeech(String? line) {
    _mouthTimer?.cancel();
    if (!_layered || line == null || _inBackground) {
      if (_mouthOpen && mounted) setState(() => _mouthOpen = false);
      return;
    }
    // Talking mouth at ~8 Hz while a line is shown.
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 125), (_) {
      if (mounted) setState(() => _mouthOpen = !_mouthOpen);
    });
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!_layered || _inBackground) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 3000 + _random.nextInt(3000)),
      () {
        if (!mounted) return;
        if (_state == CharacterState.thinking) {
          setState(() => _eyesClosed = true);
          _unblinkTimer = Timer(const Duration(milliseconds: 120), () {
            if (mounted) setState(() => _eyesClosed = false);
          });
        }
        _scheduleBlink();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes.removeListener(_onControllerChanged);
    _speechSub?.cancel();
    _blinkTimer?.cancel();
    _mouthTimer?.cancel();
    _unblinkTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final width = size * CharacterAssets.aspectRatio;
    final reduceMotion = CharacterMotion.reduce(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      label: 'Quiz host',
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          key: const Key('character_view'),
          width: width,
          height: size,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final calm = const {
                CharacterState.idle,
                CharacterState.presenting,
                CharacterState.thinking,
                CharacterState.hurry,
              }.contains(_state);
              // The stage supplies the walk cycle; calm poses stand down.
              final pose = widget.walking && calm
                  ? CharacterPose.rest
                  : characterPose(
                      _state,
                      _anim.value,
                      intensity: widget.controller.intensity.value,
                      streakLevel: widget.controller.streakLevel,
                      reduceMotion: reduceMotion,
                    );
              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  if (pose.glow > 0.01)
                    Positioned.fill(
                      child: Opacity(
                        opacity: pose.glow.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                pose.glowColor.withValues(alpha: 0.55),
                                pose.glowColor.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(pose.dx * size, pose.dy * size),
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..rotateZ(pose.rotation)
                        ..scaleByDouble(pose.scaleX, pose.scaleY, 1, 1),
                      child: _CharacterArt(
                        width: width,
                        height: size,
                        cacheHeight: (size * dpr).round(),
                        layered: _layered,
                        eyesClosed: _eyesClosed,
                        mouthOpen: _mouthOpen,
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

class _CharacterArt extends StatelessWidget {
  final double width;
  final double height;
  final int cacheHeight;
  final bool layered;
  final bool eyesClosed;
  final bool mouthOpen;

  const _CharacterArt({
    required this.width,
    required this.height,
    required this.cacheHeight,
    required this.layered,
    required this.eyesClosed,
    required this.mouthOpen,
  });

  Widget _image(String path) => Image.asset(
    path,
    width: width,
    height: height,
    fit: BoxFit.contain,
    cacheHeight: cacheHeight,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    // Missing/corrupt art hides the character; gameplay is unaffected.
    errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
  );

  @override
  Widget build(BuildContext context) {
    if (!layered) return _image(CharacterAssets.main);
    // Layers share one canvas and origin, so they simply stack.
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(CharacterAssets.body),
          _image(CharacterAssets.armRight),
          _image(CharacterAssets.head),
          _image(
            eyesClosed ? CharacterAssets.eyesClosed : CharacterAssets.eyesOpen,
          ),
          _image(
            mouthOpen ? CharacterAssets.mouthOpen : CharacterAssets.mouthClosed,
          ),
        ],
      ),
    );
  }
}
