import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character/application/character_controller.dart';
import 'package:skillverse_app/features/character/domain/character_event.dart';
import 'package:skillverse_app/features/character/domain/character_state.dart';
import 'package:skillverse_app/features/character/presentation/character_motion.dart';
import 'package:skillverse_app/features/character/presentation/character_pose.dart';
import 'package:skillverse_app/features/character/presentation/character_speech_bubble.dart';
import 'package:skillverse_app/features/character/presentation/character_view.dart';

/// Bundle that serves everything except the character art, simulating a
/// missing or corrupt character image.
class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.contains('character')) {
      return Future.error(FlutterError('missing asset $key'));
    }
    return rootBundle.load(key);
  }
}

Widget _host(
  CharacterController controller, {
  bool disableAnimations = false,
  AssetBundle? bundle,
}) {
  Widget character = CharacterView(controller: controller, size: 160);
  // Only the character gets the broken bundle; fonts etc. keep working.
  if (bundle != null) {
    character = DefaultAssetBundle(bundle: bundle, child: character);
  }
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Row(
          children: [
            character,
            Expanded(child: CharacterSpeechBubble(controller: controller)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders every state and disposes without leaks', (tester) async {
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(find.byKey(const Key('character_view')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    const events = [
      CharacterEvent.gameStarted(),
      CharacterEvent.questionShown(),
      CharacterEvent.timerTick(0.6),
      CharacterEvent.timerTick(0.1),
      CharacterEvent.resultCorrect(),
      CharacterEvent.resultWrong(),
      CharacterEvent.timeExpired(),
      CharacterEvent.streakReached(5),
      CharacterEvent.gameEnded(won: false),
    ];
    for (final event in events) {
      controller.send(event);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);

    // Leave the screen: view first, then the controller.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing character art never breaks the screen', (tester) async {
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller, bundle: _BrokenBundle()));
    await tester.pump();
    controller.send(const CharacterEvent.resultCorrect());
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('character_view')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('idle loop is bounded and stops when backgrounded', (
    tester,
  ) async {
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    // Left alone, the loop ends by itself (near-zero idle cost).
    await tester.pumpAndSettle(
      const Duration(seconds: 1),
      EnginePhase.sendSemanticsUpdate,
      const Duration(minutes: 3),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('strict reduce motion keeps the character static', (
    tester,
  ) async {
    CharacterMotion.respectReduceMotion = true;
    addTearDown(() => CharacterMotion.respectReduceMotion = false);
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller, disableAnimations: true));
    controller.send(const CharacterEvent.resultCorrect());
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('keeps moving even when the OS has animations turned off', (
    tester,
  ) async {
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('speech bubble shows and hides a line', (tester) async {
    final controller = CharacterController();
    await tester.pumpWidget(_host(controller));
    controller.send(const CharacterEvent.resultWrong());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(controller.currentSpeech!), findsOneWidget);

    await tester.pump(CharacterController.speechDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.currentSpeech, isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  group('characterPose', () {
    test('reduce motion removes all movement', () {
      for (final state in CharacterState.values) {
        final pose = characterPose(state, 0.5, reduceMotion: true);
        expect(pose.dx, 0);
        expect(pose.dy, 0);
        expect(pose.rotation, 0);
        expect(pose.scaleX, 1);
        expect(pose.scaleY, 1);
      }
    });

    test('hurry shakes harder as intensity grows', () {
      final calm = characterPose(CharacterState.hurry, 1, intensity: 0);
      final urgent = characterPose(CharacterState.hurry, 1, intensity: 1);
      expect(urgent.rotation.abs(), greaterThan(calm.rotation.abs()));
    });

    test('correct pops then returns to scale 1', () {
      expect(characterPose(CharacterState.correct, 0).scaleX, closeTo(1, 1e-9));
      expect(
        characterPose(CharacterState.correct, 0.5).scaleX,
        closeTo(1.08, 1e-9),
      );
      expect(characterPose(CharacterState.correct, 1).scaleX, closeTo(1, 1e-9));
    });

    test('streak escalates with the level', () {
      final small = characterPose(CharacterState.streak, 0.5, streakLevel: 1);
      final big = characterPose(CharacterState.streak, 0.5, streakLevel: 3);
      expect(big.scaleX, greaterThan(small.scaleX));
    });

    test('timeout sinks about 8px-equivalent and recovers', () {
      expect(characterPose(CharacterState.timeout, 0.3).dy, greaterThan(0));
      expect(characterPose(CharacterState.timeout, 1).dy, closeTo(0, 1e-9));
    });
  });
}
