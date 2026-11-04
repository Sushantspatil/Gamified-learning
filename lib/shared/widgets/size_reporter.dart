import 'package:flutter/widgets.dart';

/// Tells its parent how big [child] turned out to be, after layout.
///
/// Used to share out left-over space: measure the content that must always
/// fit, and give whatever remains to something flexible (such as the 3D
/// character). It reports after the frame, so it never changes the layout it is
/// measuring and cannot loop: the reported size only changes when the content
/// itself changes.
class SizeReporter extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSize;

  const SizeReporter({super.key, required this.child, required this.onSize});

  @override
  State<SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<SizeReporter> {
  Size? _last;

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final size = box.size;
    if (_last != null &&
        (size.width - _last!.width).abs() < 0.5 &&
        (size.height - _last!.height).abs() < 0.5) {
      return;
    }
    _last = size;
    widget.onSize(size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }
}
