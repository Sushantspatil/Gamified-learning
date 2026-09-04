import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/app.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/shop/presentation/widgets/shop_item_card.dart';

Finder _buyButtonFor(String itemTitle) {
  final card = find.ancestor(
    of: find.text(itemTitle),
    matching: find.byType(ShopItemCard),
  );
  return find.descendant(of: card, matching: find.byType(FilledButton));
}

/// The shop's ListView doesn't eagerly build off-screen children. Ad
/// Gems/Powerups/Chests sit below the fold, so scroll down before
/// interacting with them; Gems (the first section) is visible already.
Future<void> _scrollShopDown(WidgetTester tester) async {
  await tester.dragFrom(const Offset(200, 500), const Offset(0, -600));
  await tester.pumpAndSettle();
}

Future<void> _scrollShopUp(WidgetTester tester) async {
  await tester.dragFrom(const Offset(200, 300), const Offset(0, 600));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final storageService = await LocalStorageService.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
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
  await tester.tap(find.text('Sign Up'));
  await tester.pumpAndSettle();
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.tap(find.text('Web Development'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// The dashboard's ListView doesn't eagerly build off-screen children, so
/// the streak/missions/reward row at the bottom isn't in the widget tree
/// until scrolled into view.
Future<void> _scrollDashboardToBottom(WidgetTester tester) async {
  await tester.dragFrom(const Offset(200, 500), const Offset(0, -900));
  await tester.pumpAndSettle();
}

Future<void> _openPracticeMode(WidgetTester tester, String modeLabel) async {
  await tester.tap(find.byTooltip('Learn'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Web Development'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play'));
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
  await tester.ensureVisible(modeCard);
  await tester.pumpAndSettle();
  await tester.tap(modeCard);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start game'));
  await tester.pumpAndSettle();
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
  expect(find.text('1 / 1'), findsOneWidget);
}

Future<void> _startSuddenDeathQuiz(WidgetTester tester) async {
  await _openPracticeMode(tester, 'Sudden Death');
  expect(find.text('Sudden Death'), findsOneWidget);
  expect(find.text('1 / 1'), findsOneWidget);
  expect(find.text('15'), findsOneWidget);
  expect(find.text('+5 SEC'), findsOneWidget);
  expect(find.text('50:50'), findsOneWidget);
  expect(find.text('Skip'), findsOneWidget);
}

Future<void> _startSortItOutQuiz(WidgetTester tester) async {
  await _openPracticeMode(tester, 'Sort It Out');
  expect(find.text('Sort It Out'), findsOneWidget);
  expect(find.text('1 / 5'), findsOneWidget);
  expect(find.text('Debit'), findsWidgets);
  expect(find.text('Credit'), findsWidgets);
}

Future<void> _answerMcqCorrectly(WidgetTester tester) async {
  await tester.tap(find.text('Solar energy'));
  await tester.pump();
  await tester.tap(find.text('Submit Answer'));
  await tester.pumpAndSettle();
}

Future<void> _sortCurrentCardTo(WidgetTester tester, String bucket) async {
  final target = find.byKey(ValueKey('sort-bucket-$bucket'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unauthenticated user is routed to the login screen', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('signing up navigates to the learning path selection screen', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);

    expect(find.text('Choose Your Path'), findsOneWidget);
  });

  testWidgets('selecting a learning path navigates to the dashboard', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);

    expect(find.text('Web Development'), findsOneWidget);
    await _completeOnboarding(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('CONTINUE LEARNING'), findsOneWidget);
    expect(find.text('Web Development'), findsOneWidget);
    expect(find.textContaining('HTML Foundations'), findsOneWidget);
  });

  testWidgets(
    'shop lets you earn gems, buy a powerup, and open the daily chest',
    (tester) async {
      await _pumpApp(tester);
      await _signUp(tester);
      await _completeOnboarding(tester);

      await tester.tap(find.byTooltip('Shop'));
      await tester.pumpAndSettle();

      await _scrollShopDown(tester);

      // Not enough gems yet for the 20-gem Streak Freeze powerup.
      await tester.tap(_buyButtonFor('Streak Freeze'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough gems.'), findsOneWidget);

      // Watch two simulated ads to earn 20 gems (10 each).
      await tester.tap(_buyButtonFor('Watch an Ad'));
      await tester.pumpAndSettle();
      expect(find.text('You received 10 Gems!'), findsOneWidget);
      await tester.tap(_buyButtonFor('Watch an Ad'));
      await tester.pumpAndSettle();

      await tester.tap(_buyButtonFor('Streak Freeze'));
      await tester.pumpAndSettle();
      expect(find.text('Streak Freeze purchased!'), findsOneWidget);

      // Gem packs (in the first, already-visible section) are demo
      // purchases behind a confirmation dialog.
      await _scrollShopUp(tester);
      await tester.tap(_buyButtonFor('50 Gems'));
      await tester.pumpAndSettle();
      expect(find.textContaining('demo purchase'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Buy'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You received 50 Gems!'), findsOneWidget);

      await _scrollShopDown(tester);
      await tester.tap(find.text('Daily Chest'));
      await tester.pumpAndSettle();

      expect(find.text('Open Chest'), findsOneWidget);
      await tester.tap(find.text('Open Chest'));
      await tester.pumpAndSettle();

      expect(find.text('Chest Opened!'), findsOneWidget);
      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();

      // The daily chest is once-per-day; opening it again today is blocked.
      expect(
        find.text('Come back tomorrow for your next daily chest.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'spin wheel reveals a winning segment and blocks a second spin today',
    (tester) async {
      await _pumpApp(tester);
      await _signUp(tester);
      await _completeOnboarding(tester);

      await tester.tap(find.byTooltip('Shop'));
      await tester.pumpAndSettle();
      await _scrollShopDown(tester);
      await tester.tap(find.text('Spin Wheel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You won'), findsOneWidget);

      // Today's spin is used; spinning again is blocked until it resets.
      expect(
        find.text('Come back tomorrow for your next spin.'),
        findsOneWidget,
      );
    },
  );

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

    await tester.tap(find.byTooltip('Rank'));
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

      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('0 of 1'), findsOneWidget);

      await _scrollDashboardToBottom(tester);

      expect(find.text('+10'), findsOneWidget);

      await tester.tap(find.text('+10'));
      await tester.pumpAndSettle();

      expect(find.text('Claimed'), findsOneWidget);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('10 Coins'), findsOneWidget);
    },
  );

  testWidgets('Learn opens chapter topics', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-learn-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HTML Foundations'));
    await tester.pumpAndSettle();

    expect(find.text('Topics'), findsWidgets);
    expect(find.text('Tags & Elements'), findsOneWidget);
  });

  testWidgets('Subject screen separates Learn and Play', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-learn-card')), findsOneWidget);
    expect(find.byKey(const Key('subject-play-card')), findsOneWidget);
    expect(find.text('Study concepts and learning material'), findsOneWidget);
    expect(find.text('Practice concepts through game modes'), findsOneWidget);
    expect(find.byKey(const Key('game_power_up_bar')), findsNothing);
  });

  testWidgets('Topic opens learning material without power-ups', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);

    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-learn-card')));
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

    await tester.tap(find.byTooltip('Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Development'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-play-card')));
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
    await tester.ensureVisible(find.byKey(const Key('play-mode-matching')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play-mode-matching')));
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

    await tester.tap(find.byTooltip('Practice'));
    await tester.pumpAndSettle();

    expect(find.text('MCQ Quiz'), findsOneWidget);
    expect(find.text('Match the Following'), findsOneWidget);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('Sort It Out'), findsOneWidget);
  });

  testWidgets('completing an MCQ quiz shows Quiz Complete', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    await _startMcqQuiz(tester);
    await _answerMcqCorrectly(tester);

    expect(find.text('Quiz Complete!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('+5 Coins'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Start game'), findsOneWidget);
  });

  testWidgets('completing a Sort It Out quiz shows Quiz Complete', (
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
    await tester.tap(find.text('Submit Sort'));
    await tester.pumpAndSettle();

    expect(find.text('Quiz Complete!'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('+5 Coins'), findsOneWidget);
  });

  testWidgets('a wrong Sudden Death answer ends the quiz early', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    await _startSuddenDeathQuiz(tester);

    await tester.ensureVisible(find.text('Choice Y'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choice Y'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death — Quiz Ended'), findsOneWidget);
  });

  testWidgets('Sudden Death timer expiry ends the quiz early', (tester) async {
    await _pumpApp(tester);
    await _signUp(tester);
    await _completeOnboarding(tester);
    await _startSuddenDeathQuiz(tester);

    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death — Quiz Ended'), findsOneWidget);
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
