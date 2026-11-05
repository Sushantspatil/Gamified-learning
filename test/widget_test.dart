import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/app.dart';
import 'package:skillverse_app/app/router/route_names.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/shared/widgets/app_button.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/chapters/data/datasources/mock/chapter_mock_datasource.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/mock/learning_path_mock_datasource.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/profile/data/datasources/mock/profile_mock_datasource.dart';
import 'package:skillverse_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:skillverse_app/features/streaks/data/datasources/mock/streak_mock_datasource.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

Finder _buyButtonFor(String itemTitle) =>
    find.widgetWithText(FilledButton, 'Buy').first;

Future<void> _pumpApp(WidgetTester tester) async {
  await _pumpAppWithInitialValues(tester, {});
}

Future<void> _pumpAppWithInitialValues(
  WidgetTester tester,
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final storageService = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        learningPathDatasourceProvider.overrideWithValue(
          LearningPathMockDatasource(),
        ),
        chapterDatasourceProvider.overrideWithValue(ChapterMockDatasource()),
        questionDatasourceProvider.overrideWithValue(QuestionMockDatasource()),
        quizDatasourceProvider.overrideWithValue(QuizMockDatasource()),
        profileDatasourceProvider.overrideWithValue(ProfileMockDatasource()),
        streakDatasourceProvider.overrideWithValue(StreakMockDatasource()),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
      ],
      child: const SkillverseApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _signUp(WidgetTester tester) async {
  await tester.tap(find.text("Don't have an account? Sign up"));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Display name'),
    'Ada',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'ada@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm password'),
    'password123',
  );
  await tester.tap(find.text('Send verification code'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('signup-otp-field')), '123456');
  await tester.tap(find.text('Verify and create account'));
  await tester.pumpAndSettle();
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  expect(find.text('Choose Your Avatar'), findsOneWidget);
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();

  expect(find.text('Tell Us About You'), findsOneWidget);
  await tester.tap(find.byKey(const Key('setup-class-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('12th').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();

  expect(find.text('Select Your Subjects'), findsOneWidget);
  await tester.tap(find.text('Web Development'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();

  expect(find.text('Confirm Your Profile'), findsOneWidget);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  expect(find.text('How to Play'), findsOneWidget);
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Start Learning'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _openPracticeMode(WidgetTester tester, String modeLabel) async {
  await tester.tap(find.byTooltip('Play'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-subject-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Web Development').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('HTML Foundations').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-topic-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tags & Elements').last);
  await tester.pumpAndSettle();
  final modeCard = find.byKey(ValueKey('play-mode-${_routeValue(modeLabel)}'));
  await tester.ensureVisible(modeCard.first);
  await tester.pumpAndSettle();
  await tester.tap(modeCard.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start game'));
  await _pumpUntilFound(tester, find.text(modeLabel), maxPumps: 20);
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 10,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
}

String _routeValue(String modeLabel) {
  return switch (modeLabel) {
    'MCQ Quiz' => 'mcq',
    'Match the Following' => 'matching',
    'Sort It Out' => 'sortItOut',
    'Sudden Death' => 'suddenDeath',
    _ => throw ArgumentError('Unknown mode: $modeLabel'),
  };
}

Future<void> _startMcqQuiz(WidgetTester tester) async {
  await _openPracticeMode(tester, 'MCQ Quiz');
  expect(find.text('MCQ Quiz'), findsOneWidget);
  expect(find.text('1 / 5'), findsOneWidget);
}

Future<void> _startSortItOutQuiz(WidgetTester tester) async {
  await _openPracticeMode(tester, 'Sort It Out');
  expect(find.text('Sort It Out'), findsOneWidget);
  expect(find.text('1 / 5'), findsOneWidget);
  expect(find.text('Debit'), findsWidgets);
  expect(find.text('Credit'), findsWidgets);
  await tester.tap(find.text('Start sorting'));
  await tester.pump();
}

Future<void> _answerAllMcqCorrectly(WidgetTester tester) async {
  const answers = ['Solar energy', '<h1>', 'color', 'A hyperlink', 'let'];
  for (var index = 0; index < answers.length; index++) {
    expect(find.text('${index + 1} / 5'), findsOneWidget);
    final answer = find.text(answers[index]);
    await tester.ensureVisible(answer);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(answer);
    await tester.pump(const Duration(milliseconds: 250));
    final next = find.text(
      index == answers.length - 1 ? 'Submit quiz' : 'Next',
    );
    await tester.ensureVisible(next);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(next);
    await _pumpUntilFound(
      tester,
      index == answers.length - 1
          ? find.text('Quiz Complete')
          : find.text('${index + 2} / 5'),
      maxPumps: 20,
    );
  }
}

Future<void> _sortCurrentCardTo(WidgetTester tester, String bucket) async {
  final target = find.byKey(ValueKey('sort-bucket-$bucket'));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _finishSortTransition(tester);
}

Future<void> _finishSortTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 336));
  await tester.pump(const Duration(milliseconds: 600));
  // Await shared scoring after the final feedback, without consuming the next fall.
  await tester.pump(const Duration(milliseconds: 400));
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('unauthenticated user is routed to the login screen', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('signing up navigates to profile setup', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);

    expect(find.text('Choose Your Avatar'), findsOneWidget);
  });

  testWidgets('completing first-time onboarding navigates to dashboard', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);

    await _completeOnboarding(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    expect(find.text('Class 12th - Maharashtra State Board'), findsOneWidget);
    expect(find.text('Web Development'), findsOneWidget);
    expect(find.textContaining('HTML Foundations'), findsOneWidget);
  });

  testWidgets('profile setup validates details and subject selection', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);

    await tester.tap(find.byKey(const Key('setup-avatar-robot')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setup-class-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11th').last);
    await tester.pumpAndSettle();
    final detailsNext = tester.widget<AppButton>(
      find.byKey(const Key('setup-next-button')),
    );
    expect(detailsNext.onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Ada',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final subjectsNext = tester.widget<AppButton>(
      find.byKey(const Key('setup-next-button')),
    );
    expect(subjectsNext.onPressed, isNull);

    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Your Profile'), findsOneWidget);
    expect(find.text('11th'), findsOneWidget);
    expect(find.text('Maharashtra State Board'), findsOneWidget);
    expect(find.text('Web Development'), findsOneWidget);
  });

  testWidgets('tutorial skip completes onboarding and opens dashboard', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setup-class-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12th').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Learn at Your Pace'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
  });

  testWidgets('completed onboarding state skips setup and tutorial', (
    tester,
  ) async {
    await _pumpAppWithInitialValues(tester, {
      'current_user_id': 'mock-user-0',
      'selected_learning_path_id': 'web-dev',
      'profile_mock-user-0': jsonEncode({
        'avatarId': 'robot',
        'classLevel': '12th',
        'board': 'Maharashtra State Board',
        'selectedSubjectIds': ['web-dev'],
        'profileSetupCompleted': true,
        'tutorialCompleted': true,
        'xp': 0,
        'level': 1,
      }),
    });

    expect(find.text('Choose Your Avatar'), findsNothing);
    expect(find.text('How to Play'), findsNothing);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('shop purchase flow: cancel keeps coins, confirm deducts them', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Shop'));
    await tester.pumpAndSettle();

    // Cancelling a purchase leaves the balance and the item untouched.
    await tester.tap(_buyButtonFor('Scholar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coin_balance')), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    // Confirming deducts the price (100) and shows a success message.
    await tester.tap(_buyButtonFor('Scholar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Purchase'));
    await tester.pumpAndSettle();
    expect(
      find.text('Purchase successful! Scholar is now yours.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('spin wheel reveals a prize and blocks a second spin today', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    // Reached by route: the dashboard has unrelated layout overflows in the
    // test viewport once scrolled, which would mask this flow.
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push(RouteNames.spinWheel);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spin Now'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Congratulations!'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Today's spin is used; spinning again is blocked until it resets.
    expect(find.byKey(const Key('already_spun')), findsOneWidget);
  });

  testWidgets('a cosmetic can be purchased with coins and then equipped', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Shop'));
    await tester.pumpAndSettle();

    // Buy a coin pack (demo purchase) to afford a cosmetic.
    await tester.tap(_buyButtonFor('200 Coins'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Buy'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You received 200 Coins!'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compact_profile_header')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cosmetics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cosmetics'));
    await tester.pumpAndSettle();

    final goldFrameCard = find.byKey(const ValueKey('cosmetic-frame-gold'));
    expect(
      find.descendant(of: goldFrameCard, matching: find.text('100 Coins')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: goldFrameCard, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: goldFrameCard, matching: find.text('Equip')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: goldFrameCard, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: goldFrameCard, matching: find.text('Equipped')),
      findsOneWidget,
    );
  });

  testWidgets('leaderboard shows global rankings and coming-soon tabs', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Leaderboard').last);
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 400), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Grace H.'), findsOneWidget);

    // Ada starts at 0 XP, so she sorts to the bottom of the list.
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Ada (You)'), findsOneWidget);

    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(find.text('Friends leaderboard is coming soon.'), findsOneWidget);

    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    expect(find.text('School leaderboard is coming soon.'), findsOneWidget);
  });

  testWidgets(
    'dashboard shows the streak, a daily mission, and a claimable reward',
    (tester) async {
      await _pumpApp(tester);
      await _signUp(tester);
      await _completeOnboarding(tester);

      // The list builds lazily: scroll each block into view in turn.
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('+10'), 200, scrollable: page);
      await tester.tap(find.text('+10'));
      await tester.pumpAndSettle();
      expect(find.text('Claimed'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Your streak'),
        200,
        scrollable: page,
      );
      await tester.scrollUntilVisible(
        find.text('0 of 1'),
        200,
        scrollable: page,
      );

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('10 Coins'), findsOneWidget);
    },
  );

  testWidgets('Subjects opens chapter topics', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTML Foundations'));
    await tester.pumpAndSettle();

    expect(find.text('Topics'), findsWidgets);
    expect(find.text('Tags & Elements'), findsOneWidget);
  });

  testWidgets('Subjects flow stays focused on learning', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();

    expect(find.text('Learn Web Development'), findsOneWidget);
    expect(
      find.text('Study chapters, concepts, and explanations.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('subject-play-card')), findsNothing);
    expect(find.byKey(const Key('game_power_up_bar')), findsNothing);
  });

  testWidgets('Topic opens learning material without power-ups', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTML Foundations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags & Elements'));
    await tester.pumpAndSettle();

    expect(find.text('Learning material'), findsOneWidget);
    expect(find.text('Study content'), findsOneWidget);
    expect(find.text('Examples'), findsOneWidget);
    expect(find.byKey(const Key('game_power_up_bar')), findsNothing);
    expect(find.text('Practice This Topic'), findsNothing);
  });

  testWidgets('Play setup filters topics and launches Match It', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play-subject-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start game'));
    await tester.pumpAndSettle();
    final startButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Start game'),
        matching: find.byType(TextButton),
      ),
    );
    expect(startButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTML Foundations').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play-topic-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Tags & Elements'), findsWidgets);
    expect(find.text('Selectors'), findsNothing);

    await tester.tap(find.text('Tags & Elements').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('play-mode-matching')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play-mode-matching')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('match_it_view')), findsOneWidget);
  });

  testWidgets('practice hub exposes the four quiz modes and opens Match It', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('play-mode-mcq')).first);
    expect(find.text('MCQ'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('play-mode-matching')).first,
    );
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('Sort It Out'), findsOneWidget);
  });

  testWidgets('completing an MCQ quiz shows Quiz Complete', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    await _startMcqQuiz(tester);
    await _answerAllMcqCorrectly(tester);

    expect(find.text('Quiz Complete!'), findsOneWidget);
    expect(find.text('+55 XP'), findsOneWidget);
    expect(find.text('+15 Coins'), findsOneWidget);

    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Start game'), findsOneWidget);
  });

  testWidgets('Sort It Out completes, reviews answers and Play again resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    await _startSortItOutQuiz(tester);

    await _sortCurrentCardTo(tester, 'debit');
    await _sortCurrentCardTo(tester, 'debit');
    await _sortCurrentCardTo(tester, 'debit');
    await _sortCurrentCardTo(tester, 'credit');
    await _sortCurrentCardTo(tester, 'credit');
    await tester.pumpAndSettle();

    expect(find.text('Sort It Out — Results'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('+5 Coins'), findsOneWidget);
    expect(find.text('5 of 5 correct'), findsOneWidget);
    expect(find.text('Answer review'), findsOneWidget);
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start sorting'));
    await tester.pump();
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('0 correct · 0 wrong'), findsOneWidget);
    final fallingCard = find.byKey(const Key('sort-active-card'));
    final playfield = find.byKey(const Key('sort-playfield'));
    expect(
      tester.getTopLeft(fallingCard).dy,
      closeTo(tester.getTopLeft(playfield).dy, 1),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.getTopLeft(fallingCard).dy,
      greaterThan(tester.getTopLeft(playfield).dy),
    );
    await _sortCurrentCardTo(tester, 'credit');
    await _sortCurrentCardTo(tester, 'credit');
    await _sortCurrentCardTo(tester, 'credit');
    await _sortCurrentCardTo(tester, 'debit');
    await _sortCurrentCardTo(tester, 'debit');
    expect(find.text('Sort It Out — Results'), findsOneWidget);
    expect(find.text('0 of 5 correct'), findsOneWidget);
    expect(find.text('0 / 10 points'), findsOneWidget);
    expect(find.text('+0 XP'), findsOneWidget);
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start sorting'));
    await tester.pump();
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 4016));
      await _finishSortTransition(tester);
    }
    expect(find.text('Sort It Out — Results'), findsOneWidget);
    expect(find.text('0 of 5 correct'), findsOneWidget);
    expect(find.text('Missed'), findsNWidgets(5));
  });

  testWidgets(
    'viewing and editing the profile updates the displayed name and avatar',
    (tester) async {
      await _pumpApp(tester);
      await _signUp(tester);
      await _completeOnboarding(tester);

      await tester.tap(find.byKey(const Key('compact_profile_header')));
      await tester.pumpAndSettle();

      // The Dashboard stays mounted underneath (this is a push, not a
      // redirect) and reactively shows the same auth/profile state, so
      // widgets backed by global providers may legitimately match more than
      // once here — assert presence, not an exact count.
      expect(find.text('Ada'), findsWidgets);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('Class 12th - Maharashtra State Board'), findsOneWidget);
      expect(find.text('Web Development'), findsWidgets);
      expect(find.text('0 Coins'), findsOneWidget);

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Display name'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Ada Lovelace',
      );
      await tester.tap(find.byIcon(Icons.smart_toy).first);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.byIcon(Icons.smart_toy), findsWidgets);
    },
  );

  testWidgets('logging out from profile returns to the login screen', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byKey(const Key('compact_profile_header')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
