import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/features/character/domain/character_state.dart';
import 'package:skillverse_app/features/character/domain/character_strings.dart';
import 'package:skillverse_app/features/character/presentation/character_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';

McqQuestion _question(String id, String prompt) => McqQuestion(
  id: id,
  topicId: 'topic',
  prompt: prompt,
  points: 10,
  options: const [
    QuestionOption(id: 'a', text: 'Revenue'),
    QuestionOption(id: 'b', text: 'Inventory'),
    QuestionOption(id: 'c', text: 'Expense'),
    QuestionOption(id: 'd', text: 'Capital'),
  ],
  correctOptionId: 'b',
);

Widget _app(
  McqQuestion question,
  List<Answer> submitted, {
  int index = 0,
  int total = 3,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(
        body: McqQuestionView(
          question: question,
          currentIndex: index,
          totalQuestions: total,
          currentStreak: 0,
          coins: 0,
          energy: 0,
          onExit: () {},
          onSubmit: submitted.add,
        ),
      ),
    ),
  );
}

const _verdictTopics = [
  SpeechTopic.correct,
  SpeechTopic.wrong,
  SpeechTopic.timeout,
  SpeechTopic.hurry,
  SpeechTopic.streak,
  SpeechTopic.streakBig,
];

const _verdictStates = [
  CharacterState.correct,
  CharacterState.wrong,
  CharacterState.timeout,
  CharacterState.hurry,
  CharacterState.streak,
];

void main() {
  testWidgets('full MCQ run: intro, presenting, thinking, finish', (
    tester,
  ) async {
    final submitted = <Answer>[];
    await tester.pumpWidget(_app(_question('q1', 'First?'), submitted));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(McqQuestionView)),
    );
    final character = container.read(characterControllerProvider);

    // First question starts the game with the intro.
    expect(character.state.value, CharacterState.intro);
    expect(
      CharacterStrings.lines[SpeechTopic.intro],
      contains(character.currentSpeech),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(character.state.value, CharacterState.idle);

    // Submitting moves on at once (no added delay) and looks "thinking".
    await tester.tap(find.text('Inventory'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(character.state.value, CharacterState.thinking);
    await tester.pumpAndSettle();
    expect(submitted, hasLength(1));

    // Next question: presenting, no intro replay.
    await tester.pumpWidget(
      _app(_question('q2', 'Second?'), submitted, index: 1),
    );
    await tester.pump();
    expect(character.state.value, CharacterState.presenting);

    // Final question: finishing celebrates completion.
    await tester.pumpWidget(
      _app(_question('q3', 'Third?'), submitted, index: 2),
    );
    await tester.pump();
    await tester.tap(find.text('Capital'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Submit quiz'));
    await tester.pump();
    expect(character.state.value, CharacterState.win);
    expect(
      CharacterStrings.lines[SpeechTopic.win],
      contains(character.currentSpeech),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('right and wrong answers look identical to the character', (
    tester,
  ) async {
    final seen = <String, List<CharacterState>>{};

    for (final choice in ['Inventory', 'Revenue']) {
      await tester.pumpWidget(
        _app(_question('q-$choice', 'Pick'), <Answer>[]),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(McqQuestionView)),
      );
      final character = container.read(characterControllerProvider);
      final states = seen[choice] = [];
      final lines = <String?>[];
      character.state.addListener(() => states.add(character.state.value));
      character.speech.listen(lines.add);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text(choice));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      for (final topic in _verdictTopics) {
        for (final line in lines.whereType<String>()) {
          expect(CharacterStrings.lines[topic], isNot(contains(line)));
        }
      }
      for (final state in states) {
        expect(_verdictStates, isNot(contains(state)));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    expect(seen['Inventory'], seen['Revenue']);
  });

  testWidgets('leaving mid-game disposes the character cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_question('q1', 'Leave?'), <Answer>[]));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'character fits without overflow at ${size.width.toInt()}x'
        '${size.height.toInt()} ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _app(
              _question(
                'q1',
                'A very long question prompt that keeps going so the '
                'character has to shrink and the options still have to fit '
                'on screen without any overflow at all?',
              ),
              <Answer>[],
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            ),
          );
          await tester.pump(const Duration(seconds: 2));

          expect(
            find.byKey(const Key('mcq_character_section')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }

  testWidgets('character is hidden in landscape', (tester) async {
    tester.view.physicalSize = const Size(915, 412);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_question('q1', 'Landscape?'), <Answer>[]));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('mcq_character_section')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
