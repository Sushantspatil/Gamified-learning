import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

/// Moves the character along a [Character3dFraming.strip] view. Pass it to a
/// [Character3dView]; commands sent before the character is on screen are held
/// (only the latest [enter]) and run as soon as it appears, and commands sent
/// while 3D is unavailable are ignored.
class Character3dController {
  _Character3dViewState? _view;

  /// Walks in from the left edge to a resting spot, after any run-off that is
  /// still going.
  void enter({Duration duration = const Duration(milliseconds: 2800)}) =>
      _view?._command(
        'CharacterEmbed.enter(${duration.inMilliseconds})',
        isEnter: true,
      );

  /// A jump on the spot.
  void hop() => _view?._command('CharacterEmbed.hop()');

  /// Runs off the right edge.
  void exit({Duration duration = const Duration(milliseconds: 750)}) =>
      _view?._command('CharacterEmbed.exit(${duration.inMilliseconds})');
}

/// The 3D character (the rigged model from `character3d/`), drawn by a small
/// web page inside a transparent WebView.
///
/// The page is one self-contained asset (script and model included), so it
/// works offline. Until the character is on screen, and whenever it cannot run
/// (unsupported platform, WebView problem, load timeout), [fallback] is shown
/// instead, so a screen never depends on it.
///
/// The view ignores touches (scrolling passes through to the screen), stops
/// rendering while its route is covered by another screen or the app is in the
/// background, and tells the page to switch animation when [state] changes.
class Character3dView extends StatefulWidget {
  /// Asset built by `npm run build:embed` in `character3d/`.
  static const String assetPath = 'assets/character3d/character.html';

  final double height;
  final double width;
  final Character3dState state;
  final Character3dFraming framing;

  /// Shown while loading and when the 3D view is unavailable. It is removed
  /// from the tree once the character is on screen.
  final Widget fallback;

  /// Optional remote control for the walk-across [Character3dFraming.strip].
  final Character3dController? controller;

  /// How long to wait for the page before giving up.
  final Duration loadTimeout;

  const Character3dView({
    super.key,
    required this.height,
    required this.width,
    required this.fallback,
    this.state = Character3dState.walk,
    this.framing = Character3dFraming.full,
    this.controller,
    this.loadTimeout = const Duration(seconds: 25),
  });

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
  String? _pendingEnter; // an enter() sent before the character was on screen

  /// The platforms webview_flutter supports.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._view = this;
    _start();
  }

  void _start() {
    if (!_supported) {
      _failed = true;
      return;
    }
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
      _controller = controller;
      _timeout = Timer(widget.loadTimeout, () => _fail('timed out'));
    } catch (error) {
      // No WebView implementation on this platform (e.g. in widget tests).
      _failed = true;
      _controller = null;
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
      final enter = _pendingEnter;
      _pendingEnter = null;
      if (enter != null) _run(enter, force: true);
      _run('CharacterEmbed.show()', force: true);
    } else if (text == 'ready') {
      if (!_ready) setState(() => _ready = true);
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
  }

  /// A controller command: held until the character is on screen (enter only).
  void _command(String script, {bool isEnter = false}) {
    if (_failed) return;
    if (!_ready) {
      if (isEnter) _pendingEnter = script;
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

  /// Sends the current animation and framing to the page.
  void _push() {
    _run('CharacterEmbed.setState("${widget.state.name}")');
    _run('CharacterEmbed.setFraming("${widget.framing.name}")');
    _lastPaused = null;
    _applyPaused();
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
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._view == this) {
        oldWidget.controller?._view = null;
      }
      widget.controller?._view = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._view == this) widget.controller?._view = null;
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The WebView stays painted from the start (even while the page
          // loads): a hidden platform view may not render at all.
          if (controller != null && !_failed)
            ExcludeSemantics(
              child: IgnorePointer(
                child: WebViewWidget(controller: controller),
              ),
            ),
          // Fades out and is dropped once the character is visible, so a
          // fallback with its own animation stops running.
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _ready
                  ? const SizedBox.shrink(key: ValueKey('3d-on'))
                  : Center(
                      key: const ValueKey('3d-off'),
                      child: widget.fallback,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
