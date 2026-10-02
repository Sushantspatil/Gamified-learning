import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/config/app_config.dart';
import 'package:skillverse_app/app/config/environment.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chapters/domain/entities/chapter.dart';
import 'package:skillverse_app/features/chapters/domain/entities/topic.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/learning_paths/domain/entities/learning_path.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/practice/presentation/screens/practice_screen.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/sudden_death_mock_datasource.dart';
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sudden_death_preview_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/screens/sudden_death_demo_screen.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/game_power_up_bar.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_celebration_overlay.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';
import 'package:skillverse_app/shared/widgets/app_button.dart';
import 'package:skillverse_app/shared/widgets/app_pressable.dart';

const _path = LearningPath(
  id: 'accounting',
  title: 'Book-Keeping & Accountancy',
  description: 'Preview subject',
  difficulty: LearningPathDifficulty.beginner,
  topicCount: 1,
);

const _chapter = Chapter(
  id: 'accounting-basics',
  learningPathId: 'accounting',
  title: 'Book-Keeping & Accountancy',
  description: 'Preview chapter',
  order: 1,
  topicCount: 1,
);

const _topic = Topic(
  id: 'accounting',
  chapterId: 'accounting-basics',
  title: 'Introduction to Accounting',
  order: 1,
  isCompleted: false,
);

void main() {
  setUp(() {
    AppConfig.initialize(Environment.dev);
    AppConfig.developmentPreviewsOverride = null;
  });

  tearDown(() {
    AppConfig.developmentPreviewsOverride = null;
  });

  group('Sudden Death JSON Contract & Validation', () {
    test('JSON asset exists and satisfies all 2-option contract requirements', () {
      final file = File('assets/mock/sudden_death_questions.json');
      expect(file.existsSync(), isTrue, reason: 'assets/mock/sudden_death_questions.json must exist');

      final raw = file.readAsStringSync();
      final decoded = json.decode(raw) as Map<String, dynamic>;

      expect(decoded['game_mode'], 'sudden_death');
      expect(decoded['subject'], 'Book-Keeping & Accountancy');
      expect(decoded['total'], 10);
      expect(decoded['time_limit_sec'], 15);

      final questionsRaw = decoded['questions'] as List<dynamic>;
      expect(questionsRaw.length, 10, reason: 'Must contain exactly 10 questions');

      final dtos = questionsRaw
          .whereType<Map<String, dynamic>>()
          .map(SuddenDeathQuestionDto.fromJson)
          .toList();

      SuddenDeathMockDatasource.validateQuestionsContract(dtos);

      for (final q in dtos) {
        expect(q.options.length, 2, reason: 'Every Sudden Death question must have exactly 2 options');
        expect(q.options.map((o) => o.option).toSet(), contains(q.correctOption));
      }

      final easy = dtos.where((q) => q.difficulty?.toLowerCase() == 'easy').length;
      final medium = dtos.where((q) => q.difficulty?.toLowerCase() == 'medium').length;
      final hard = dtos.where((q) => q.difficulty?.toLowerCase() == 'hard').length;
      expect(easy, 4, reason: 'Must have 4 easy questions');
      expect(medium, 4, reason: 'Must have 4 medium questions');
      expect(hard, 2, reason: 'Must have 2 hard questions');
    });

    test('Loads 10 dedicated questions with NO MCQ questions reused and exactly 2 options', () {
      final datasource = const SuddenDeathMockDatasource();
      final questions = datasource.getBundledQuestions(topicId: 'accounting');

      expect(questions.length, 10);
      for (final q in questions) {
        expect(q, isA<SuddenDeathQuestion>());
        expect(q.type, QuestionType.suddenDeath);
        expect(q, isNot(isA<McqQuestion>()));
        expect(q.options.length, 2, reason: 'Sudden Death questions must have 2 options');
        expect(q.hint, isNotNull);
        expect(q.hint!.isNotEmpty, isTrue);
      }
    });
  });

  group('Play Screen Sudden Death Availability & Flow', () {
    testWidgets('Sudden Death card enabled in debug with dedicated mock count', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storageService),
            learningPathsProvider.overrideWith((ref) async => const [_path]),
            chaptersProvider.overrideWith((ref, subjectId) async => const [_chapter]),
            topicsProvider.overrideWith((ref, chapterId) async => const [_topic]),
            questionsForTopicProvider.overrideWith((ref, topicId) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const PlaySetupScreen(
              initialSubjectId: 'accounting',
              initialChapterId: 'accounting-basics',
              initialTopicId: 'accounting',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final suddenDeathCard = find.byKey(const Key('play-mode-suddenDeath'));
      expect(suddenDeathCard, findsOneWidget);
      expect(find.text('10 development preview questions'), findsOneWidget);
      expect(tester.widget<AppPressable>(suddenDeathCard).onTap, isNotNull);

      await tester.ensureVisible(suddenDeathCard);
      await tester.tap(suddenDeathCard);
      await tester.pumpAndSettle();

      final startButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Start game'),
      );
      expect(startButton.onPressed, isNotNull);
    });

    test('Release/production mode does not use mock data automatically without flag', () async {
      AppConfig.initialize(Environment.prod);
      AppConfig.developmentPreviewsOverride = false;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // In production without flag, preview questions provider returns empty
      final previewQuestions = await container.read(
        suddenDeathPreviewQuestionsProvider('accounting').future,
      );
      expect(previewQuestions, isEmpty, reason: 'Release/production must not return mock questions without flag');
    });

    test('AppConfig.enableSuddenDeathMock or override activates previews even in release mode', () async {
      AppConfig.initialize(Environment.prod);
      AppConfig.developmentPreviewsOverride = true;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final previewQuestions = await container.read(
        suddenDeathPreviewQuestionsProvider('accounting').future,
      );
      expect(previewQuestions.length, 10, reason: 'When enabled via override or build flag, 10 questions are returned');
    });
  });

  group('Sudden Death Demo Screen Gameplay UI & Features', () {
    Future<void> pumpDemo(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const SuddenDeathDemoScreen(topicId: 'accounting'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Q1 of 10 and dedicated question prompt with exactly 2 options', (tester) async {
      await pumpDemo(tester);

      expect(find.text('Sudden Death'), findsOneWidget);
      expect(find.text('1 / 10'), findsOneWidget);
      expect(
        find.text('Which account is debited when goods are purchased for cash?'),
        findsOneWidget,
      );
      expect(find.text('Purchases Account'), findsOneWidget);
      expect(find.text('Cash Account'), findsOneWidget);
      expect(find.text('Sales Account'), findsNothing);
      expect(find.text('Capital Account'), findsNothing);
    });

    testWidgets('Hint power-up displays question-specific hint', (tester) async {
      await pumpDemo(tester);

      await tester.tap(find.byKey(const Key('powerup-sudden-hint')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy & use'));
      await tester.pumpAndSettle();

      expect(
        find.text('Think about which account records goods bought for resale.'),
        findsOneWidget,
      );
    });

    testWidgets('+5 SEC power-up adds time', (tester) async {
      await pumpDemo(tester);

      await tester.tap(find.byKey(const Key('powerup-sudden-time')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy & use'));
      await tester.pumpAndSettle();

      final boostedVisible = ['16', '17', '18', '19', '20']
          .any((v) => find.text(v).evaluate().isNotEmpty);
      expect(boostedVisible, isTrue);
    });

    testWidgets('50:50 power-up is disabled for 2-choice questions', (tester) async {
      await pumpDemo(tester);

      final powerUpBar = tester.widget<GamePowerUpBar>(find.byType(GamePowerUpBar));
      final fiftyFifty = powerUpBar.actions.firstWhere((a) => a.id == 'sudden-50-50');
      expect(fiftyFifty.isDisabled, isTrue);
      expect(fiftyFifty.description, 'Not available for 2-choice questions.');
    });

    testWidgets('Skip power-up moves to Q2 with neutral feedback and zero streak', (tester) async {
      await pumpDemo(tester);

      expect(find.text('1 / 10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('powerup-sudden-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy & use'));
      await tester.pumpAndSettle();

      expect(find.text('2 / 10'), findsOneWidget);
      expect(find.text('What type of account is Cash Account?'), findsOneWidget);
    });

    testWidgets('Wrong answer triggers eliminated result preview without rewards', (tester) async {
      await pumpDemo(tester);

      // Select wrong option 'b' (Cash Account) for Q1
      final wrongOption = find.byKey(const Key('sudden-option-b'));
      await tester.ensureVisible(wrongOption);
      await tester.tap(wrongOption);
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminated'), findsOneWidget);
      expect(find.text('0 survived'), findsOneWidget);
      expect(
        find.text('UI preview — no score or rewards were calculated'),
        findsOneWidget,
      );
      expect(
        tester.widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay)).enabled,
        isFalse,
      );
    });

    testWidgets('Timeout triggers time up result preview', (tester) async {
      await pumpDemo(tester);

      await tester.pump(SuddenDeathConfig.questionTimeLimit);
      await tester.pumpAndSettle();

      expect(find.text("Time's up"), findsOneWidget);
      expect(
        tester.widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay)).enabled,
        isFalse,
      );
    });

    testWidgets('Full 10-question successful run leads to Sudden Death cleared', (tester) async {
      await pumpDemo(tester);

      const correctAnswers = ['a', 'a', 'b', 'a', 'b', 'a', 'b', 'a', 'b', 'a'];
      for (var i = 0; i < correctAnswers.length; i++) {
        expect(find.text('${i + 1} / 10'), findsOneWidget);
        final option = find.byKey(Key('sudden-option-${correctAnswers[i]}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Sudden Death cleared'), findsOneWidget);
      expect(find.text('10 survived'), findsOneWidget);
      expect(
        tester.widget<QuizCelebrationOverlay>(find.byType(QuizCelebrationOverlay)).enabled,
        isTrue,
      );
    });
  });

  group('Sudden Death Screen Responsiveness', () {
    for (final size in <Size>[
      const Size(320, 568),
      const Size(393, 852),
      const Size(430, 932),
    ]) {
      testWidgets('remains overflow-free at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              home: const SuddenDeathDemoScreen(topicId: 'accounting'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Submit'), findsOneWidget);
        expect(find.byKey(const Key('game_power_up_bar')), findsOneWidget);
      });
    }
  });
}
