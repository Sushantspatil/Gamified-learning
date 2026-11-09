import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics_service.dart';
import 'analytics_providers.dart';

/// Wraps the home screen to report app opens and to send queued events when the
/// app goes to the background.
///
/// "Opened" means the app started or came back to the front; the first
/// [AnalyticsHost] of a run reports `source: launch`, later returns report
/// `source: resume`.
class AnalyticsHost extends ConsumerStatefulWidget {
  final Widget child;

  const AnalyticsHost({super.key, required this.child});

  /// Whether this run of the app has already reported its launch. A home screen
  /// that is rebuilt (navigating away and back) must not count as a new open.
  static bool _launchReported = false;

  /// Forgets that the launch was reported (for tests).
  @visibleForTesting
  static void resetForTest() => _launchReported = false;

  @override
  ConsumerState<AnalyticsHost> createState() => _AnalyticsHostState();
}

class _AnalyticsHostState extends ConsumerState<AnalyticsHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AnalyticsHost._launchReported) {
      AnalyticsHost._launchReported = true;
      // After the first frame, when the signed-in player is known.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(analyticsServiceProvider).track(AnalyticsEvents.appOpen, {
            'source': 'launch',
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final analytics = ref.read(analyticsServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        analytics.track(AnalyticsEvents.appOpen, {'source': 'resume'});
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        analytics.flush();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
