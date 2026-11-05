import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/app_theme_colors.dart';

/// What the 3D character is doing. The model has these three loops.
enum Character3dState { idle, walk, run }

/// How much of the character is in view.
enum Character3dFraming {
  full,
  bust,
  face,

  /// A wide, short banner: the character walks along it (see
  /// [Character3dController]).
  strip,
}

/// One-off gestures the model can perform on the spot.
enum Character3dAction {
  /// Waves the right hand.
  wave('wave'),

  /// Both arms up and two jumps: a victory cheer.
  cheer('cheer'),

  /// Head down, shoulders low. Held until stopped.
  sad('sad'),

  /// Hand to chin. Held until stopped.
  think('think'),

  /// Applause.
  clap('clap'),

  /// Looks left, then right.
  lookAround('lookaround');

  /// The name the page knows it by.
  final String id;

  const Character3dAction(this.id);
}

/// What the player has equipped, shown on the character: [frame] as a glowing
/// ring at its feet, [avatar] as a small emblem floating above its head.
@immutable
class Character3dCosmetics {
  /// 'scholar' | 'explorer' | 'champion' | 'genius', or null.
  final String? avatar;

  /// 'bronze' | 'silver' | 'gold', or null.
  final String? frame;

  const Character3dCosmetics({this.avatar, this.frame});

  static const none = Character3dCosmetics();

  /// From shop ids such as 'avatar-scholar' / 'frame-gold'.
  factory Character3dCosmetics.fromShopIds({
    String? avatarId,
    String? frameId,
  }) {
    String? tail(String? id) => id?.split('-').last;
    return Character3dCosmetics(avatar: tail(avatarId), frame: tail(frameId));
  }

  String toJson() => jsonEncode({'avatar': avatar, 'frame': frame});

  @override
  bool operator ==(Object other) =>
      other is Character3dCosmetics &&
      other.avatar == avatar &&
      other.frame == frame;

  @override
  int get hashCode => Object.hash(avatar, frame);
}

/// Where the 3D character is in its life.
enum Character3dStatus {
  /// The page is loading; the placeholder is shown.
  loading,

  /// The character is on screen.
  ready,

  /// 3D cannot run here (unsupported platform, WebView error, timeout); the
  /// fallback is shown.
  unavailable,
}

/// Remote control for a [Character3dView]: gestures, and the walk-across
/// [Character3dFraming.strip]. Commands sent before the character is on screen
/// are held (only the latest [enter] / [play]); commands sent while 3D is
/// unavailable are ignored.
class Character3dController {
  _Character3dViewState? _view;

  /// Loading, ready or unavailable. Listen to react (e.g. hide a bubble).
  final ValueNotifier<Character3dStatus> status = ValueNotifier(
    Character3dStatus.loading,
  );

  /// Walks in from the left edge to the centre, after any run-off still going.
  /// With [thenThink] it ends in a thinking pose.
  void enter({
    Duration duration = const Duration(milliseconds: 2800),
    bool thenThink = false,
  }) => _view?._command(
    'CharacterEmbed.enter(${duration.inMilliseconds}, $thenThink)',
    hold: 'enter',
  );

  /// A jump on the spot.
  void hop() => _view?._command('CharacterEmbed.hop()');

  /// One graceful spin on the spot (the happy reaction used while playing).
  void twirl() => _view?._command('CharacterEmbed.twirl()');

  /// Runs off the right edge.
  void exit({Duration duration = const Duration(milliseconds: 750)}) =>
      _view?._command('CharacterEmbed.exit(${duration.inMilliseconds})');

  /// Performs [action] on the spot.
  void play(Character3dAction action) =>
      _view?._command('CharacterEmbed.play("${action.id}")', hold: 'play');

  /// A burst of sparkles above the character.
  void sparkle() => _view?._command('CharacterEmbed.sparkle()');

  /// Ends a held action (sad, think) and returns to the relaxed pose.
  void stopAction() => _view?._command('CharacterEmbed.stopAction()');

  void dispose() => status.dispose();
}

/// The 3D character (the rigged model from `character3d/`), drawn by a small
/// web page inside a transparent WebView.
///
/// The page is one self-contained asset (script and model included), so it
/// works offline. While it loads, [placeholder] is shown (a still picture of
/// the character is ideal); if 3D cannot run, [fallback] is shown instead, so a
/// screen never depends on it.
///
/// The view ignores touches (scrolling passes through to the screen), stops
/// rendering while its route is covered by another screen or the app is in the
/// background, and tells the page to switch animation when [state] changes.
class Character3dView extends StatefulWidget {
  /// Page built by `npm run build:embed` in `character3d/`.
  static const String assetPath = 'assets/character3d/character.html';

  /// A still picture of the character, for [placeholder] while loading.
  static const String posterAsset = 'assets/character3d/poster.png';

  final double height;
  final double width;
  final Character3dState state;
  final Character3dFraming framing;

  /// Shown when 3D is unavailable (and while loading, unless [placeholder] is
  /// given). It is removed from the tree once the character is visible.
  final Widget fallback;

  /// Shown while the page loads. Defaults to [fallback]; pass
  /// `SizedBox.shrink()` to show nothing until the character appears.
  final Widget? placeholder;

  /// When true the character does not pop in: it fades in softly the moment
  /// it is ready (pair it with an empty [placeholder]).
  final bool arrive;

  /// Optional remote control (gestures, walk-across, status).
  final Character3dController? controller;

  /// What the player has equipped.
  final Character3dCosmetics cosmetics;

  /// Now and then, while idle, the character looks around or waves.
  final bool ambient;

  /// A gesture to perform as soon as the character appears.
  final Character3dAction? initialAction;

  /// How long to wait for the page before giving up.
  final Duration loadTimeout;

  const Character3dView({
    super.key,
    required this.height,
    required this.width,
    required this.fallback,
    this.placeholder,
    this.arrive = false,
    this.state = Character3dState.walk,
    this.framing = Character3dFraming.full,
    this.controller,
    this.cosmetics = Character3dCosmetics.none,
    this.ambient = false,
    this.initialAction,
    this.loadTimeout = const Duration(seconds: 25),
  });

  /// Starts the system WebView engine early (it takes a moment the first time),
  /// so the first character appears sooner. Safe to call anywhere and any
  /// number of times; does nothing where WebView is unsupported.
  static void prewarm() {
    if (_prewarmed || !_supported) return;
    _prewarmed = true;
    // Decode the still picture now, so it is on screen the instant a card opens.
    try {
      const AssetImage(posterAsset)
          .resolve(ImageConfiguration.empty)
          .addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
    } catch (_) {
      // best effort
    }
    try {
      WebViewController().setJavaScriptMode(JavaScriptMode.disabled);
    } catch (_) {
      // No WebView implementation here (e.g. widget tests).
    }
  }

  static bool _prewarmed = false;

  /// The platforms webview_flutter supports.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<Character3dView> createState() => _Character3dViewState();
}

class _Character3dViewState extends State<Character3dView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Timer? _timeout;
  bool _loaded = false; // page has the model; waiting to be revealed
  bool _ready = false; // character is visible
  bool _failed = false;
  bool _routeActive = true;
  bool _appActive = true;
  bool? _lastPaused;
  String? _styleSent;

  /// Commands sent before the character was on screen, by kind.
  final Map<String, String> _held = {};

  bool _started = false;
  bool _scheduled = false;
  Animation<double>? _routeAnimation;
  Timer? _startFallback;
  Timer? _startBeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._view = this;
    if (!Character3dView._supported) {
      _failed = true;
      _setStatus(Character3dStatus.unavailable);
    }
  }

  /// Creating a WebView is heavy (the system builds a whole browser view), and
  /// doing it while the screen slides in makes that slide stutter. So wait until
  /// the transition has finished, plus a beat for the first frames to settle.
  /// The still poster is on screen meanwhile, so nothing looks missing.
  void _scheduleStart() {
    if (_started || _failed || _scheduled) return;
    _scheduled = true;
    // Read the route's animation one frame later: while the page is first being
    // built it still reports "completed" even though the slide has not begun.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started || _failed) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _startSoon();
        return;
      }
      _routeAnimation = animation..addStatusListener(_onRouteStatus);
      // Never wait forever (e.g. a route that never reports completion).
      _startFallback = Timer(const Duration(milliseconds: 1500), _startSoon);
    });
  }

  /// Start after the next frame plus a beat, so the frames that follow a screen
  /// change are not the ones that pay for building a browser view.
  void _startSoon() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _startFallback?.cancel();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (!mounted || _started) return;
      _startBeat?.cancel();
      _startBeat = Timer(const Duration(milliseconds: 120), () {
        if (mounted && !_started) _start();
      });
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startSoon();
  }

  void _setStatus(Character3dStatus status) {
    final notifier = widget.controller?.status;
    if (notifier == null || notifier.value == status) return;
    // Never notify listeners in the middle of a build.
    scheduleMicrotask(() {
      try {
        notifier.value = status;
      } catch (_) {
        // the controller was disposed in the meantime
      }
    });
  }

  void _start() {
    if (_started || _failed) return;
    _started = true;
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel('CharacterBridge', onMessageReceived: _onMessage)
        ..setNavigationDelegate(
          NavigationDelegate(
            // The page never navigates; refuse anything that tries to.
            onNavigationRequest: (request) =>
                request.url.startsWith('file:') ||
                    request.url.startsWith('about:') ||
                    request.url.startsWith('data:')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
            onWebResourceError: (error) {
              if (error.isForMainFrame ?? true) _fail('web resource error');
            },
          ),
        )
        ..loadFlutterAsset(Character3dView.assetPath);
      // The WebView is created after the first frames now, so the tree has to
      // be told to show it.
      setState(() => _controller = controller);
      _timeout = Timer(widget.loadTimeout, () => _fail('timed out'));
    } catch (error) {
      // No WebView implementation on this platform (e.g. in widget tests).
      if (!mounted) return;
      setState(() {
        _failed = true;
        _controller = null;
      });
      _setStatus(Character3dStatus.unavailable);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    final text = message.message;
    if (text == 'loaded') {
      // Model is in the page but hidden: set it up, then reveal it, so the
      // first visible frame is already right.
      _timeout?.cancel();
      _loaded = true;
      _push();
      for (final script in _held.values) {
        _run(script, force: true);
      }
      _held.clear();
      _run('CharacterEmbed.show()', force: true);
      final first = widget.initialAction;
      if (first != null) {
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (mounted) _run('CharacterEmbed.play("${first.id}")');
        });
      }
    } else if (text == 'ready') {
      if (!_ready) {
        setState(() => _ready = true);
        _setStatus(Character3dStatus.ready);
      }
    } else if (text.startsWith('error')) {
      _fail(text);
    }
  }

  void _fail(String reason) {
    if (!mounted || _ready || _loaded || _failed) return;
    debugPrint('Character3dView unavailable: $reason');
    _timeout?.cancel();
    setState(() {
      _failed = true;
      _controller = null; // drops the WebView
    });
    _setStatus(Character3dStatus.unavailable);
  }

  /// A controller command: held until the character is on screen (the latest
  /// of each [hold] kind only; others are dropped).
  void _command(String script, {String? hold}) {
    if (_failed) return;
    if (!_ready) {
      if (hold != null) _held[hold] = script;
      return;
    }
    _run(script);
  }

  Future<void> _run(String script, {bool force = false}) async {
    final controller = _controller;
    if (controller == null || !(_ready || _loaded || force)) return;
    try {
      await controller.runJavaScript(script);
    } catch (_) {
      // The page is gone; the fallback stays correct either way.
    }
  }

  /// Sends the current animation, framing, cosmetics and ambient mode.
  void _push() {
    _run('CharacterEmbed.setState("${widget.state.name}")');
    _run('CharacterEmbed.setFraming("${widget.framing.name}")');
    _run('CharacterEmbed.setCosmetics(${widget.cosmetics.toJson()})');
    _run('CharacterEmbed.setAmbient(${widget.ambient})');
    _pushStyle(force: true);
    _lastPaused = null;
    _applyPaused();
  }

  /// Light and sparkle colours follow the app's theme (dark / light, accent).
  void _pushStyle({bool force = false}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.themeColors.primary;
    final hex =
        '#${(accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final script = 'CharacterEmbed.setStyle({"dark":$dark,"accent":"$hex"})';
    if (!force && script == _styleSent) return;
    _styleSent = script;
    _run(script);
  }

  void _applyPaused() {
    final paused = !(_routeActive && _appActive);
    if (_lastPaused == paused) return;
    _lastPaused = paused;
    _run('CharacterEmbed.setPaused($paused)');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Covered by another route: no need to keep drawing.
    final active = TickerMode.valuesOf(context).enabled;
    if (active != _routeActive) {
      _routeActive = active;
      _applyPaused();
    }
    if (_ready || _loaded) _pushStyle(); // the theme was switched
    _scheduleStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _applyPaused();
  }

  @override
  void didUpdateWidget(Character3dView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _run('CharacterEmbed.setState("${widget.state.name}")');
    }
    if (oldWidget.framing != widget.framing) {
      _run('CharacterEmbed.setFraming("${widget.framing.name}")');
    }
    if (oldWidget.cosmetics != widget.cosmetics) {
      _run('CharacterEmbed.setCosmetics(${widget.cosmetics.toJson()})');
    }
    if (oldWidget.ambient != widget.ambient) {
      _run('CharacterEmbed.setAmbient(${widget.ambient})');
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._view == this) {
        oldWidget.controller?._view = null;
      }
      widget.controller?._view = this;
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _startFallback?.cancel();
    _startBeat?.cancel();
    if (widget.controller?._view == this) widget.controller?._view = null;
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    super.dispose();
  }

  /// Fades the live view in once it is ready (see [Character3dView.arrive]).
  Widget _arriving(Widget child) {
    if (!widget.arrive) return child;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 450);
    return AnimatedOpacity(
      key: const Key('character_arrive'),
      opacity: _ready ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget? stand = _ready
        ? null
        : (_failed ? widget.fallback : (widget.placeholder ?? widget.fallback));
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The WebView stays painted from the start (even while the page
          // loads): a hidden platform view may not render at all.
          if (controller != null && !_failed)
            _arriving(
              ExcludeSemantics(
                child: IgnorePointer(
                  child: WebViewWidget(controller: controller),
                ),
              ),
            ),
          // Fades out and is dropped once the character is visible, so a
          // placeholder with its own animation stops running.
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: stand == null
                  ? const SizedBox.shrink(key: ValueKey('3d-on'))
                  : Center(
                      key: ValueKey(_failed ? '3d-failed' : '3d-loading'),
                      child: stand,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A still picture of the character, for [Character3dView.placeholder]: the
/// same pose and framing the live view starts in, so the switch is seamless.
class Character3dPoster extends StatelessWidget {
  final double height;

  const Character3dPoster({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Character3dView.posterAsset,
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );
  }
}
