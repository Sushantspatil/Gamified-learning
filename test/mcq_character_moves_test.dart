import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';

/// Regression: the character must actually move around inside the real MCQ
/// view (not only in isolated stage tests).
void main() {
  for (final animationsOff in [false, true]) {
    testWidgets('character moves in the MCQ view (OS animations off: '
        '$animationsOff)', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      const question = McqQuestion(
        id: 'q',
        topicId: 't',
        prompt: '7 x 9 = ?',
        points: 10,
        options: [
          QuestionOption(id: 'a', text: '63'),
          QuestionOption(id: 'b', text: '73'),
        ],
        correctOptionId: 'a',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                disableAnimations: animationsOff,
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: McqQuestionView(
                    key: const ValueKey('q'),
                    question: question,
                    currentIndex: 1,
                    totalQuestions: 10,
                    currentStreak: 0,
                    coins: 0,
                    energy: 0,
                    onExit: () {},
                    onSubmit: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // The 3D page starts a few frames after the view appears; wait for it.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final xs = <int>{};
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        xs.add(
          tester.getTopLeft(find.byKey(const Key('character_view'))).dx.round(),
        );
      }
      // Several distinct horizontal positions within ten seconds.
      expect(xs.length, greaterThan(5));
      expect(
        xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
        greaterThan(60),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
