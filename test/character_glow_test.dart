import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character3d/presentation/character_glow.dart';

Future<void> _show(
  WidgetTester tester, {
  required ThemeData theme,
  bool reduceMotion = false,
  Widget? child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            height: 150,
            child: CharacterGlow(
              child: child ?? const SizedBox(key: Key('inner')),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The colour of the glow's centre, from its radial gradient.
double _peakAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(CharacterGlow),
      matching: find.byType(DecoratedBox),
    ),
  );
  final gradient =
      (box.decoration as BoxDecoration).gradient! as RadialGradient;
  return gradient.colors.first.a;
}

void main() {
  testWidgets('the glow is stronger on dark cards than on light ones', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.lightTheme, reduceMotion: true);
    await tester.pumpAndSettle();
    final light = _peakAlpha(tester);
    await _show(tester, theme: AppTheme.darkTheme, reduceMotion: true);
    await tester.pumpAndSettle(); // the theme change animates
    final dark = _peakAlpha(tester);
    expect(dark, greaterThan(light));
    expect(light, greaterThan(0));
  });

  testWidgets('it breathes, then settles so the screen can go idle', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.darkTheme);
    await tester.pump(const Duration(milliseconds: 2500));
    final mid = _peakAlpha(tester);
    await tester.pump(const Duration(milliseconds: 2500));
    final end = _peakAlpha(tester);
    expect(mid, isNot(closeTo(end, 0.001))); // it moves...
    await tester.pumpAndSettle(); // ...but not forever
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps it still and fully visible', (
    tester,
  ) async {
    await _show(tester, theme: AppTheme.darkTheme, reduceMotion: true);
    final a = _peakAlpha(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_peakAlpha(tester), a);
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
