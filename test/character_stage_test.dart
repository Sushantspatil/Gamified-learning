import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/features/character/application/character_controller.dart';
import 'package:skillverse_app/features/character/domain/character_event.dart';
import 'package:skillverse_app/features/character/presentation/character_stage.dart';
import 'package:skillverse_app/features/character/presentation/character_speech_bubble.dart';

void main() {
  testWidgets('character changes sides as the game moves on', (tester) async {
    final controller = CharacterController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: CharacterStage(controller: controller, height: 120),
          ),
        ),
      ),
    );
    Alignment side() =>
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
            as Alignment;

    expect(side(), Alignment.centerLeft);

    controller.send(const CharacterEvent.questionShown()); // presenting
    await tester.pump();
    expect(side(), Alignment.centerRight);

    await tester.pump(const Duration(seconds: 2)); // settles to idle: no move
    expect(side(), Alignment.centerRight);

    controller.send(const CharacterEvent.answerSubmitted()); // thinking
    await tester.pump();
    expect(side(), Alignment.centerLeft);

    // Bubble sits on the free side, never under the character.
    controller.send(const CharacterEvent.resultCorrect());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    final bubble = tester.getRect(
      find.descendant(
        of: find.byType(CharacterSpeechBubble),
        matching: find.byType(DecoratedBox),
      ),
    );
    final character = tester.getRect(find.byKey(const Key('character_view')));
    expect(bubble.overlaps(character), isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
