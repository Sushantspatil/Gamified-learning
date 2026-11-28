import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import '../chest_style.dart';
import 'chest_effects_painter.dart';

/// Where a chest's Rive animation lives (see docs/chest-rive-guide.md).
String chestRiveAsset(ChestStyle style) =>
    'assets/chests/rive/${style.name}.riv';

/// Plays a chest's Rive animation (`assets/chests/rive/<style>.riv`) and shows
/// [fallback] (the picture film, [ChestOpenView]) whenever that is not
/// possible: no file for this chest yet, reduce motion, or a file that cannot
/// be loaded. It never blocks the opening or the reward.
///
/// The file's contract, kept deliberately small so it can be made in the
/// Rive editor without code:
/// - the default artboard and its default state machine are used;
/// - `open` is fired when the opening starts: a Trigger property of the
///   artboard's view model (Data Binding), or a Trigger input of the state
///   machine (older files);
/// - optionally, `progress` (Number, same two places) follows the opening
///   from 0 to 100 on every frame, for files that scrub a timeline instead.
///
/// The screen keeps its own timing ([progress], 2.6 s): the reward appears
/// when [progress] completes, so the Rive animation should last about as long
/// and end on the open chest.
class ChestRiveView extends StatefulWidget {
  final ChestStyle style;
  final Animation<double> progress;
  final double height;
  final bool reduceMotion;
  final Widget fallback;

  /// Where the file and the asset list are read from (tests pass their own).
  final AssetBundle? bundle;

  const ChestRiveView({
    super.key,
    required this.style,
    required this.progress,
    required this.height,
    required this.fallback,
    this.reduceMotion = false,
    this.bundle,
  });

  @override
  State<ChestRiveView> createState() => _ChestRiveViewState();
}

/// Loaded files, shared by every opening (a file is read once per app run).
final Map<String, Future<rive.File?>> _files = {};

/// The native Rive runtime, started once; `false` where it cannot run.
Future<bool>? _native;

/// The Rive file of [style], read once and shared; null when the chest has no
/// file or it cannot be read. Never throws.
Future<rive.File?> _fileFor(ChestStyle style, AssetBundle bundle) async {
  final path = chestRiveAsset(style);
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    if (!manifest.listAssets().contains(path)) return null; // not made yet
  } catch (_) {
    return null;
  }
  return _files[path] ??= _readFile(path, bundle);
}

Future<rive.File?> _readFile(String path, AssetBundle bundle) async {
  try {
    final ready = await (_native ??= rive.RiveNative.init().catchError(
      (Object _) => false,
    ));
    if (!ready) return null;
    return await rive.File.asset(
      path,
      riveFactory: rive.Factory.rive,
      bundle: bundle,
    );
  } catch (error) {
    debugPrint('Chest Rive file $path could not be read: $error');
    return null;
  }
}

/// Starts reading every chest's Rive file in the background, so an opening
/// can play it from its first frame. Call it when the chest screen opens.
void precacheChestRive({AssetBundle? bundle}) {
  for (final style in ChestStyle.values) {
    _fileFor(style, bundle ?? rootBundle);
  }
}

/// Waits, at most [timeout], for [style]'s Rive file, so the opening does not
/// start on the picture film while the file is still loading. Never throws.
Future<void> chestRiveReady(
  ChestStyle style, {
  AssetBundle? bundle,
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  try {
    await _fileFor(style, bundle ?? rootBundle).timeout(timeout);
  } catch (_) {
    // Too slow or unreadable: the opening plays the picture film.
  }
}

/// Too far into the opening to switch from the picture film to Rive without
/// a visible jump: the rest of this opening stays on the film.
const double _latestSwitch = 0.12;

class _ChestRiveViewState extends State<ChestRiveView> {
  rive.RiveWidgetController? _controller;
  // Data Binding (current Rive editor) ...
  rive.ViewModelInstance? _viewModel;
  rive.ViewModelInstanceTrigger? _openProperty;
  rive.ViewModelInstanceNumber? _progressProperty;
  // ... or state machine inputs (older files).
  rive.TriggerInput? _openInput;
  rive.NumberInput? _progressInput;
  bool _useRive = false;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    if (!widget.reduceMotion) _load();
  }

  Future<void> _load() async {
    try {
      final file = await _fileFor(widget.style, widget.bundle ?? rootBundle);
      if (file == null || !mounted) return;
      if (widget.progress.value > _latestSwitch) return;
      final controller = rive.RiveWidgetController(file);
      _controller = controller;
      _bind(controller);
      setState(() => _useRive = true);
      _onProgress();
    } catch (error) {
      // A broken or mismatched file must never break the chest screen.
      debugPrint('Chest Rive animation not used: $error');
    }
  }

  void _bind(rive.RiveWidgetController controller) {
    try {
      final vm = controller.dataBind(rive.DataBind.auto());
      _viewModel = vm;
      _openProperty = vm.trigger('open');
      _progressProperty = vm.number('progress');
    } catch (_) {
      // No view model in this file: use state machine inputs.
    }
    if (_openProperty == null) {
      // ignore: deprecated_member_use
      _openInput = controller.stateMachine.trigger('open');
    }
    if (_progressProperty == null) {
      // ignore: deprecated_member_use
      _progressInput = controller.stateMachine.number('progress');
    }
  }

  void _onProgress() {
    if (!_useRive) return;
    final t = widget.progress.value;
    _progressProperty?.value = t * 100;
    _progressInput?.value = t * 100;
    if (!_fired && t > 0) {
      _fired = true;
      _openProperty?.trigger();
      _openInput?.fire();
    }
  }

  @override
  void didUpdateWidget(ChestRiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    _openProperty?.dispose();
    _progressProperty?.dispose();
    _viewModel?.dispose();
    _openInput?.dispose();
    _progressInput?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_useRive || controller == null) return widget.fallback;
    return ChestRiveFrame(
      key: const Key('chest_rive_view'),
      style: widget.style,
      progress: widget.progress,
      height: widget.height,
      child: rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
    );
  }
}

/// The Rive chest with the app's own light drawn behind it: the same glow,
/// rays and particles as the picture film ([ChestEffectsPainter]), so a Rive
/// file only has to animate the chest itself.
class ChestRiveFrame extends StatelessWidget {
  final ChestStyle style;
  final Animation<double> progress;
  final double height;
  final Widget child;

  const ChestRiveFrame({
    super.key,
    required this.style,
    required this.progress,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * style.aspectRatio,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('chest_rive_effects'),
                painter: ChestEffectsPainter(style: style, progress: progress),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// For tests: forget files read in earlier tests.
@visibleForTesting
void resetChestRiveCache() => _files.clear();
