import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character3d/presentation/character_glow.dart';

Future<void> _show(
  WidgetTester tester, {
  required ThemeData theme,
  bool reduceMotion = false,
  Widget? child,
  Size box = const Size(120, 150),
  Widget Function(Widget child)? wrap,
}) async {
  final glow = wrap != null
      ? wrap(child ?? const SizedBox(key: Key('inner')))
      : CharacterGlow(child: child ?? const SizedBox(key: Key('inner')));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: box.width, height: box.height, child: glow),
        ),
      ),
    ),
  );
}

GlowPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const Key('character_glow_light')))
            .painter!
        as GlowPainter;

void main() {
  testWidgets('the glow is stronger on dark cards than on light ones', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.lightTheme, reduceMotion: true);
    await tester.pumpAndSettle();
    final light = _painter(tester).peakAlpha;
    await _show(tester, theme: AppTheme.darkTheme, reduceMotion: true);
    await tester.pumpAndSettle(); // the theme change animates
    final dark = _painter(tester).peakAlpha;
    expect(dark, greaterThan(light));
    expect(light, greaterThan(0));
  });

  testWidgets('it breathes, then settles so the screen can go idle', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.darkTheme);
    await tester.pump(const Duration(milliseconds: 2500));
    final mid = _painter(tester).peakAlpha;
    await tester.pump(const Duration(milliseconds: 2500));
    final end = _painter(tester).peakAlpha;
    expect(mid, isNot(closeTo(end, 0.001))); // it moves...
    await tester.pumpAndSettle(); // ...but not forever
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps it still and fully visible', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.darkTheme, reduceMotion: true);
    final a = _painter(tester).peakAlpha;
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).peakAlpha, a);
    await tester.pumpAndSettle();
  });

  testWidgets('it never blocks touches on what it wraps', (tester) async {
    var taps = 0;
    await _show(
      tester,
      theme: AppTheme.darkTheme,
      reduceMotion: true,
      child: GestureDetector(
        key: const Key('hit'),
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: const SizedBox.expand(),
      ),
    );
    await tester.tap(find.byKey(const Key('hit')));
    expect(taps, 1);
  });

  group('the light stays inside its box (no square edges)', () {
    test('for every shape the app uses, the ellipse never leaves the box', () {
      const shapes = [
        Size(120, 150), // dashboard card
        Size(150, 150), // results
        Size(102, 120), // Match It, small
        Size(204, 240), // Match It / Sudden Death, large
        Size(360, 110), // the MCQ strip
        Size(140, 130), // reward dialog
      ];
      for (final size in shapes) {
        for (final glow in [
          (const Offset(0.5, 0.56), const Size(0.46, 0.46)), // normal
          (const Offset(0.5, 0.8), const Size(0.34, 0.2)), // floor
        ]) {
          final rect = GlowPainter.lightRect(size, glow.$1, glow.$2);
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$size');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '$size');
          expect(rect.right, lessThanOrEqualTo(size.width), reason: '$size');
          expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$size');
        }
      }
    });

    test('even an oversized request is clamped inside', () {
      final rect = GlowPainter.lightRect(
        const Size(100, 100),
        const Offset(0.9, 0.95),
        const Size(0.9, 0.9),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(100));
      expect(rect.bottom, lessThanOrEqualTo(100));
    });
  });

  testWidgets('the floor variant fits a wide, short strip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 110,
              child: CharacterGlow.floor(child: SizedBox()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
