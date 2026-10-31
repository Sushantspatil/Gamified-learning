import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/app/theme/theme_mode_controller.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/game_power_up_bar.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/mcq_question_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_right_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sudden_death_question_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Responsive & Text Visibility across All Game Modes', () {
    testWidgets(
      'MCQ renders long multi-sentence questions and long options without overflow',
      (tester) async {
        // Small Android viewport (360 x 640)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longPrompt =
            'Under the Written Down Value Method, depreciation is calculated each year on the opening book value of the asset. How does this accounting treatment affect asset valuation over successive accounting periods in comparison to the Straight Line Method?';

        final options = [
          const QuestionOption(
            id: 'opt-1',
            text:
                'The depreciation expense decreases every consecutive accounting year, leaving a residual book value.',
          ),
          const QuestionOption(
            id: 'opt-2',
            text:
                'The original historical cost remains constant and is never adjusted across periods.',
          ),
          const QuestionOption(
            id: 'opt-3',
            text:
                'Equal fixed amounts of depreciation are debited each financial year until zero.',
          ),
          const QuestionOption(
            id: 'opt-4',
            text:
                'Market valuation completely overrides historical book value at every balance sheet date.',
          ),
        ];

        final question = McqQuestion(
          id: 'q-mcq-long',
          topicId: 'accounting_depreciation',
          points: 10,
          prompt: longPrompt,
          options: options,
          correctOptionId: 'opt-1',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: McqQuestionView(
                  question: question,
                  currentIndex: 0,
                  totalQuestions: 10,
                  currentStreak: 2,
                  coins: 100,
                  energy: 50,
                  onExit: () {},
                  onSubmit: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify full question text is mounted and visible
        expect(find.text(longPrompt), findsOneWidget);
        for (final opt in options) {
          expect(find.text(opt.text), findsOneWidget);
        }

        // Verify no RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Sudden Death renders long question, long options, and power-up bar on small viewport without overflow',
      (tester) async {
        // Small Android viewport (360 x 640)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longPrompt =
            'Which accounting principle mandates that revenue should only be recognized when realized or realizable, and expenses matched in the identical reporting period?';

        final options = [
          const QuestionOption(
            id: 'opt-a',
            text:
                'The revenue realization and matching principle under standard GAAP framework.',
          ),
          const QuestionOption(
            id: 'opt-b',
            text:
                'The historical cost valuation convention applied strictly to fixed assets.',
          ),
          const QuestionOption(
            id: 'opt-c',
            text:
                'The conservatism principle recognizing all probable future liabilities immediately.',
          ),
          const QuestionOption(
            id: 'opt-d',
            text:
                'The going concern assumption presuming indefinite operational horizon.',
          ),
        ];

        final suddenQuestion = SuddenDeathQuestion(
          id: 'sd-long-1',
          prompt: longPrompt,
          points: 15,
          options: options,
          correctOptionId: 'opt-a',
          topicId: 'accounting_principles',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SuddenDeathQuestionView(
                  question: suddenQuestion,
                  currentIndex: 0,
                  totalQuestions: 10,
                  currentStreak: 4,
                  bestStreak: 7,
                  energy: 95,
                  coins: 650,
                  onExit: () {},
                  isPreviewMode: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify title, question, and options rendered
        expect(find.text('Sudden Death'), findsOneWidget);
        expect(find.text(longPrompt), findsOneWidget);
        expect(find.text(options[0].text), findsOneWidget);
        expect(find.text('Current streak'), findsOneWidget);
        expect(find.text('Best streak: 7'), findsOneWidget);

        // Verify power-up bar buttons render without overflow
        expect(find.byType(GamePowerUpBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Sudden Death renders cleanly in Light Theme with High Text Scale (1.3x)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final suddenQuestion = SuddenDeathQuestion(
          id: 'sd-light-1',
          prompt:
              'What constitutes owners equity in a corporate balance sheet?',
          points: 10,
          correctOptionId: 'a',
          options: const [
            QuestionOption(
              id: 'a',
              text: 'Common stock plus retained earnings minus treasury stock',
            ),
            QuestionOption(
              id: 'b',
              text: 'Current assets minus current liabilities',
            ),
          ],
          topicId: 'accounting_equity',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: Scaffold(
                  body: SuddenDeathQuestionView(
                    question: suddenQuestion,
                    currentIndex: 2,
                    totalQuestions: 10,
                    currentStreak: 2,
                    bestStreak: 5,
                    energy: 80,
                    coins: 400,
                    onExit: () {},
                    isPreviewMode: true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Sudden Death'), findsOneWidget);
        expect(
          find.text(
            'What constitutes owners equity in a corporate balance sheet?',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Match the Following handles long pair texts without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final question = MatchTheFollowingQuestion(
        id: 'mtf-1',
        topicId: 'accounting_terms',
        prompt: 'Match accounting terms to their corresponding definitions:',
        points: 20,
        pairs: const [
          MatchPair(
            id: 'p1',
            left: 'Intangible Asset',
            right:
                'Patents, trademarks, and goodwill without physical substance',
          ),
          MatchPair(
            id: 'p2',
            left: 'Accrued Expense',
            right: 'Expense incurred during period but not yet paid in cash',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MatchTheFollowingView(
                question: question,
                currentIndex: 0,
                totalQuestions: 1,
                title: 'Accounting Match',
                onExit: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Accounting Match'), findsOneWidget);
      expect(find.text('Intangible Asset'), findsOneWidget);
      expect(
        find.text(
          'Patents, trademarks, and goodwill without physical substance',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Sort It Out renders dynamic categories and long cards with natural wrap',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longPrompt =
            'Cash collected in advance from customers for future delivery of services';

        final cards = [
          const SortItOutCard(
            id: 'sort_1',
            prompt: longPrompt,
            points: 10,
            options: [
              QuestionOption(id: 'a', text: 'Debit'),
              QuestionOption(id: 'b', text: 'Credit'),
            ],
            correctOption: 'b',
            pairType: 'credit_debit',
          ),
          const SortItOutCard(
            id: 'sort_2',
            prompt:
                'Office equipment purchased for long-term administrative operations',
            points: 10,
            options: [
              QuestionOption(id: 'a', text: 'Debit'),
              QuestionOption(id: 'b', text: 'Credit'),
            ],
            correctOption: 'a',
            pairType: 'credit_debit',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SortItRightView(
                  cards: cards,
                  currentIndex: 0,
                  totalQuestions: 2,
                  currentStreak: 1,
                  coins: 50,
                  energy: 80,
                  onExit: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Debit'), findsWidgets);
        expect(find.text('Credit'), findsWidgets);
        expect(find.text(longPrompt), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Theme Switching & Persistence Tests', () {
    test('Theme preference persists across controller reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      // 1. Initial default is dark
      final container1 = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container1.dispose);

      expect(
        container1.read(themeModeControllerProvider),
        AppThemePreference.dark,
      );

      // 2. Toggle to light
      container1.read(themeModeControllerProvider.notifier).toggleTheme();
      expect(
        container1.read(themeModeControllerProvider),
        AppThemePreference.light,
      );

      // Verify persisted in storage
      expect(storage.getString(StorageKeys.themePreference), 'light');

      // 3. New container simulate app restart
      final container2 = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container2.dispose);

      // Restored preference is light
      expect(
        container2.read(themeModeControllerProvider),
        AppThemePreference.light,
      );

      // 4. Toggle back to dark
      container2.read(themeModeControllerProvider.notifier).toggleTheme();
      expect(
        container2.read(themeModeControllerProvider),
        AppThemePreference.dark,
      );
      expect(storage.getString(StorageKeys.themePreference), 'dark');
    });
  });
}
