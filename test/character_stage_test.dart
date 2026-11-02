import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character/application/character_controller.dart';
import 'package:skillverse_app/features/character/domain/character_event.dart';
import 'package:skillverse_app/features/character/presentation/character_speech_bubble.dart';
import 'package:skillverse_app/features/character/presentation/character_stage.dart';

Future<CharacterController> _pumpStage(
  WidgetTester tester, {
  bool animationsOff = false,
  bool wander = true,
}) async {
  final controller = CharacterController();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: animationsOff),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: CharacterStage(
                controller: controller,
                height: 120,
                wander: wander,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// Bottom-centre of the character: unaffected by the rock and mirror.
Offset _character(WidgetTester tester) {
  final finder = find.byKey(const Key('character_view'));
  return (tester.getBottomLeft(finder) + tester.getBottomRight(finder)) / 2;
}

Future<void> _teardown(WidgetTester tester, CharacterController c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  testWidgets('walks at a steady pace to the other end, bouncing per step', (
    tester,
  ) async {
    final controller = await _pumpStage(tester, wander: false);
    final startX = _character(tester).dx;

    controller.send(const CharacterEvent.questionShown()); // walk right
    await tester.pump();

    final xs = <double>[];
    final ys = <double>{};
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = _character(tester);
      xs.add(p.dx);
      ys.add(double.parse(p.dy.toStringAsFixed(1)));
    }

    // Moves continuously rightwards (never jumps back) ...
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThanOrEqualTo(xs[i - 1] - 0.01));
    }
    expect(xs.last - startX, greaterThan(250));
    // ... in small steps, not a teleport or a single slide.
    final biggestJump = [
      for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1],
    ].reduce((a, b) => a > b ? a : b);
    expect(biggestJump, lessThan(25));
    // Vertical bounce from the step cycle.
    expect(ys.length, greaterThan(4));

    await _teardown(tester, controller);
  });

  testWidgets('faces the direction of travel (mirrored when going left)', (
    tester,
  ) async {
    final controller = await _pumpStage(tester, wander: false);
    final startX = _character(tester).dx;

    bool mirrored() => tester
        .widgetList<Transform>(find.byType(Transform))
        .any((t) => t.transform.storage[0] < 0);

    controller.send(const CharacterEvent.questionShown()); // right
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(mirrored(), isFalse);
    await tester.pump(const Duration(seconds: 4));

    controller.send(const CharacterEvent.answerSubmitted()); // back left
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(mirrored(), isTrue);

    await tester.pump(const Duration(seconds: 4));
    expect(_character(tester).dx, closeTo(startX, 1)); // back at the left end
    expect(mirrored(), isFalse); // standing again

    await _teardown(tester, controller);
  });

  testWidgets('strolls on its own while idle, even with OS animations off', (
    tester,
  ) async {
    final controller = await _pumpStage(tester, animationsOff: true);
    final xs = <int>{};
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      xs.add(_character(tester).dx.round());
    }
    expect(xs.length, greaterThan(10));

    await _teardown(tester, controller);
  });

  testWidgets('stops strolling after a while with no game activity', (
    tester,
  ) async {
    final controller = await _pumpStage(tester);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 500),
      EnginePhase.sendSemanticsUpdate,
      const Duration(minutes: 5),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await _teardown(tester, controller);
  });

  testWidgets('speech bubble never overlaps the character', (tester) async {
    final controller = await _pumpStage(tester);
    controller.send(const CharacterEvent.resultCorrect());

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final bubbles = find.descendant(
        of: find.byType(CharacterSpeechBubble),
        matching: find.byType(DecoratedBox),
      );
      if (bubbles.evaluate().isEmpty) continue;
      final bubble = tester.getRect(bubbles.first);
      final character = tester.getRect(find.byKey(const Key('character_view')));
      expect(bubble.overlaps(character), isFalse, reason: 'frame $i');
    }
    expect(tester.takeException(), isNull);

    await _teardown(tester, controller);
  });
}
