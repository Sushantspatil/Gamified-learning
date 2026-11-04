import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character3d/presentation/character_3d_view.dart';
import 'package:skillverse_app/features/character3d/presentation/result_mascot.dart';
import 'package:skillverse_app/features/dashboard/presentation/widgets/mascot_card.dart';

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('3D character is optional', () {
    testWidgets('without a WebView the fallback shows and nothing throws', (
      tester,
    ) async {
      await _show(
        tester,
        const Character3dView(
          width: 120,
          height: 150,
          fallback: Text('fallback'),
        ),
      );
      expect(find.text('fallback'), findsOneWidget);
      expect(
        tester.getSize(find.byType(Character3dView)),
        const Size(120, 150),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('state and framing changes are accepted while unavailable', (
      tester,
    ) async {
      Widget view(Character3dState s) => Character3dView(
        width: 100,
        height: 100,
        state: s,
        fallback: const Text('fallback'),
      );
      await _show(tester, view(Character3dState.walk));
      await _show(tester, view(Character3dState.idle));
      expect(find.text('fallback'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strip controller commands are harmless without 3D', (
      tester,
    ) async {
      final controller = Character3dController();
      controller.enter(); // before any view exists
      await _show(
        tester,
        Character3dView(
          width: 300,
          height: 120,
          framing: Character3dFraming.strip,
          controller: controller,
          fallback: const Text('fallback'),
        ),
      );
      controller
        ..enter()
        ..hop()
        ..exit();
      await tester.pump();
      expect(find.text('fallback'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The view going away detaches it; later commands still do nothing.
      await tester.pumpWidget(const SizedBox());
      controller
        ..enter()
        ..hop();
      expect(tester.takeException(), isNull);
    });

    testWidgets('results mascot shows the trophy when 3D is unavailable', (
      tester,
    ) async {
      await _show(
        tester,
        const ResultMascot(unsuccessful: false, trophy: Text('trophy')),
      );
      expect(find.text('trophy'), findsOneWidget);
      expect(tester.getSize(find.byType(ResultMascot)).height, 150);
    });

    testWidgets('dashboard card greets the learner and fits a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136); // 320 x 568
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: MascotCard(displayName: 'Asha Rao', streak: 4),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text("Let's go, Asha!"), findsOneWidget);
      expect(find.textContaining('4-day streak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new learner with no streak gets a starting prompt', (
      tester,
    ) async {
      await _show(tester, const MascotCard(displayName: '', streak: 0));
      expect(find.text('Ready to learn?'), findsOneWidget);
      expect(find.textContaining('start your streak'), findsOneWidget);
    });
  });

  test('the bundled page exists and carries the model and the bridge', () {
    final page = File(Character3dView.assetPath);
    expect(page.existsSync(), isTrue, reason: 'run npm run build:embed');
    final text = page.readAsStringSync();
    expect(text, contains('window.__CHARACTER_GLB_B64'));
    expect(text, contains('CharacterBridge'));
    expect(text, contains('CharacterEmbed'));
    expect(text.length, greaterThan(1000000)); // script + model inside
  });
}
