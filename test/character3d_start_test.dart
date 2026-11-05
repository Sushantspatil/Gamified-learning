import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character3d/presentation/character_3d_view.dart';

/// The 3D page is only created once the screen that shows it has finished
/// sliding in, so opening a game screen never stutters because of it. Here the
/// platform is pretended to be Android; there is no real WebView in tests, so
/// "starting" is visible as the status leaving `loading` (it becomes
/// `unavailable` as soon as creating the WebView is attempted).
/// Pumps real-looking frames (16 ms apart) for [total]: the start waits for a
/// frame to finish, which a single big pump would not provide.
Future<void> pumpFrames(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(const Duration(milliseconds: 16));
    elapsed += const Duration(milliseconds: 16);
  }
}

void main() {
  testWidgets('the WebView is not created until the route has settled', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = Character3dController();
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Character3dView(
            width: 100,
            height: 100,
            controller: controller,
            placeholder: const Text('poster'),
            fallback: const Text('fallback'),
          ),
        ),
      ),
    );

    // Mid-transition: the poster is up, nothing has been started.
    await tester.pump();
    await pumpFrames(tester, const Duration(milliseconds: 100));
    expect(find.text('poster'), findsOneWidget);
    expect(controller.status.value, Character3dStatus.loading);

    // The slide ends, but the first frames get a beat before the start.
    await pumpFrames(tester, const Duration(milliseconds: 250));
    expect(controller.status.value, Character3dStatus.loading);

    // Then it starts (and, with no WebView in a test, falls back cleanly).
    await pumpFrames(tester, const Duration(milliseconds: 600));
    expect(controller.status.value, Character3dStatus.unavailable);
    expect(find.text('fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('leaving before the start never creates it or throws', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Character3dView(
            width: 100,
            height: 100,
            fallback: Text('fallback'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    navigator.currentState!.pop(); // back out mid-transition
    await tester.pumpAndSettle();
    await tester.pump(
      const Duration(seconds: 2),
    ); // the pending start must not run
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a view that is already on screen starts after a short beat', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = Character3dController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Character3dView(
            width: 100,
            height: 100,
            controller: controller,
            fallback: const Text('fallback'),
          ),
        ),
      ),
    );
    await pumpFrames(tester, const Duration(milliseconds: 500));
    expect(controller.status.value, Character3dStatus.unavailable);
    debugDefaultTargetPlatformOverride = null;
  });
}
