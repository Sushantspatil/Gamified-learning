// A developer tool, not part of the app's test suite: renders the result screens
// to PNG files so the design can be looked at without a phone.
//
//   flutter test tool/preview/result_preview_test.dart \
//     --dart-define=FONT_DIR=<folder with PlusJakartaSans-*.ttf> \
//     --dart-define=OUT_DIR=<folder to write the PNG files to> \
//     --dart-define=ICON_FONT=<path to materialicons-regular.otf>
//
// The 3D character does not run in tests, so a still picture stands in for it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/models/user_model.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/daily_missions/data/datasources/daily_mission_datasource.dart';
import 'package:skillverse_app/features/daily_missions/data/models/daily_mission_model.dart';
import 'package:skillverse_app/features/daily_missions/presentation/providers/daily_mission_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/quiz/domain/entities/match_the_following_models.dart';
import 'package:skillverse_app/features/quiz/domain/entities/question_answer_record.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_result.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/match_the_following_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/quiz_result_view.dart';
import 'package:skillverse_app/features/quiz/presentation/widgets/sort_it_out_result_view.dart';
import 'package:skillverse_app/features/streaks/data/datasources/remote/streak_rewards_remote_datasource.dart';
import 'package:skillverse_app/features/streaks/domain/entities/streak_rewards.dart';
import 'package:skillverse_app/features/streaks/presentation/providers/streak_rewards_providers.dart';
import '../../test/mocks/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:skillverse_app/shared/widgets/game_scaffold.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');
const _outDir = String.fromEnvironment('OUT_DIR');
const _iconFont = String.fromEnvironment('ICON_FONT');

Future<void> _loadFonts() async {
  if (_iconFont.isNotEmpty) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(File(_iconFont).readAsBytesSync())),
      );
    await icons.load();
  }
  if (_fontDir.isEmpty) return;
  const files = {
    'regular': 'Regular',
    '500': 'Medium',
    '600': 'SemiBold',
    '700': 'Bold',
    '800': 'ExtraBold',
  };
  for (final entry in files.entries) {
    final loader = FontLoader('PlusJakartaSans_${entry.key}');
    final bytes = File(
      '$_fontDir/PlusJakartaSans-${entry.value}.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

QuizResult _result({
  int correct = 7,
  int total = 10,
  bool endedEarly = false,
  int points = 70,
  int xp = 45,
  int coins = 18,
  List<bool>? answers,
}) {
  final flags = answers ?? [for (var i = 0; i < total; i++) i < correct];
  final prompts = [
    'Which account is credited when goods are sold for cash?',
    'What is the accounting equation?',
    'Which book records only cash transactions?',
    'A debit balance in a ledger account means...',
    'Which of these is a real account?',
    'Depreciation is charged on...',
    'The trial balance is prepared to check...',
    'Discount allowed is a...',
    'Capital is a liability of the business to the...',
    'Outstanding expenses are shown in the...',
  ];
  final records = [
    for (var i = 0; i < flags.length; i++)
      QuestionAnswerRecord(
        question: McqQuestion(
          id: 'q$i',
          topicId: 't',
          prompt: prompts[i % prompts.length],
          points: 10,
          correctOptionId: 'b',
          options: const [
            QuestionOption(id: 'a', text: 'Sales account'),
            QuestionOption(id: 'b', text: 'Cash account'),
            QuestionOption(id: 'c', text: 'Purchases account'),
            QuestionOption(id: 'd', text: 'Capital account'),
          ],
        ),
        answer: McqAnswer(
          questionId: 'q$i',
          selectedOptionId: flags[i] ? 'b' : 'a',
        ),
        evaluation: AnswerEvaluation(
          isCorrect: flags[i],
          pointsEarned: flags[i] ? 10 : 0,
        ),
      ),
  ];
  return QuizResult(
    sessionId: 'preview-$correct-$total-$endedEarly',
    topicId: 'topic-1',
    quizType: QuestionType.mcq,
    score: Score(
      earnedPoints: points,
      maxPoints: endedEarly ? 0 : 100,
      correctCount: correct,
      totalCount: total,
    ),
    records: records,
    endedEarly: endedEarly,
    streakCount: 0,
    xpAwarded: xp,
    coinsAwarded: coins,
    rewardBreakdown: const QuizRewardBreakdown(
      score: [RewardBreakdownItem(key: 'correct_answer_points', amount: 70)],
      xp: [
        RewardBreakdownItem(key: 'completion_xp', amount: 10),
        RewardBreakdownItem(key: 'correct_answer_xp', amount: 35),
      ],
      coins: [
        RewardBreakdownItem(key: 'completion_coins', amount: 5),
        RewardBreakdownItem(key: 'correct_answer_coins', amount: 13),
      ],
    ),
    levelProgress: const QuizLevelProgress(
      currentLevel: 4,
      experience: 340,
      nextLevelExperience: 500,
    ),
    timeTaken: const Duration(minutes: 1, seconds: 42),
    createdAt: DateTime(2026),
  );
}

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async =>
      const UserModel(id: 'u1', email: 'ada@example.com', displayName: 'Ada');
}

class _Goals implements DailyMissionDatasource {
  @override
  Future<List<DailyMissionModel>> getTodayMissions(String userId) async => [
    const DailyMissionModel(
      id: 'play_1',
      title: 'Finish 1 game',
      targetCount: 1,
      progressCount: 1,
      coinReward: 20,
      claimed: true,
    ),
    const DailyMissionModel(
      id: 'play_3',
      title: 'Finish 3 games',
      targetCount: 3,
      progressCount: 2,
      coinReward: 40,
    ),
    const DailyMissionModel(
      id: 'score_100',
      title: 'Score 100 points',
      targetCount: 100,
      progressCount: 70,
      coinReward: 2,
      currency: 'gems',
    ),
  ];
  @override
  Future<DailyMissionModel> recordQuizCompleted(String userId) =>
      throw UnsupportedError('x');
  @override
  Future<void> claimMission(String userId, String missionId) async {}
}

class _NoRewards implements StreakRewardsRemoteDatasource {
  @override
  Future<StreakRewards?> fetch() async => null;
  @override
  Future<void> claim(int days) async {}
  @override
  Future<void> buyFreeze() async {}
}

MatchBoardReview _board(
  String code,
  String prompt, {
  required int matched,
  required int mistakes,
  required int ms,
  bool timeout = false,
  String? explanation,
}) => MatchBoardReview(
  questionCode: code,
  prompt: prompt,
  pairsMatched: matched,
  totalPairs: 4,
  mistakes: mistakes,
  timeTakenMs: ms,
  isFlawless: matched == 4 && mistakes == 0 && !timeout,
  isTimeout: timeout,
  basePoints: 0,
  flawlessBonus: 0,
  speedBonus: 0,
  mistakePenalty: 0,
  totalBoardScore: 0,
  explanation: explanation,
);

MatchTheFollowingResult _match() => MatchTheFollowingResult(
  session: 'm1',
  totalBoards: 4,
  clearedBoards: 3,
  totalPairsMatched: 14,
  totalPairsCount: 16,
  totalMistakes: 3,
  accuracyPercentage: 82,
  finalScore: 118,
  coinsAwarded: 24,
  xpAwarded: 52,
  gemsAwarded: 3,
  scoreBreakdown: const {
    'base_points': 90,
    'flawless_bonus': 20,
    'speed_bonus': 12,
    'mistake_penalty': -4,
  },
  level: const LevelProgressDto(
    current: 4,
    didLevelUp: false,
    experience: 340,
    nextLevelExp: 500,
  ),
  boardsReview: [
    _board(
      'b1',
      'Accounting terms and their meanings',
      matched: 4,
      mistakes: 0,
      ms: 9200,
      explanation: 'Assets = Liabilities + Equity is the base of double entry.',
    ),
    _board(
      'b2',
      'Which book records what?',
      matched: 4,
      mistakes: 2,
      ms: 18400,
      explanation: 'The cash book records only cash and bank transactions.',
    ),
    _board(
      'b3',
      'Match the account to its type',
      matched: 4,
      mistakes: 0,
      ms: 7800,
    ),
    _board(
      'b4',
      'Financial statements and what they show',
      matched: 2,
      mistakes: 1,
      ms: 25000,
      timeout: true,
    ),
  ],
);

const _sortCards = [
  SortItOutCard(
    id: 'q1',
    prompt: 'Bank loan',
    points: 10,
    options: [
      QuestionOption(id: 'a', text: 'Debit'),
      QuestionOption(id: 'b', text: 'Credit'),
    ],
    correctOption: 'b',
  ),
  SortItOutCard(
    id: 'q2',
    prompt: 'Office equipment',
    points: 10,
    options: [
      QuestionOption(id: 'a', text: 'Debit'),
      QuestionOption(id: 'b', text: 'Credit'),
    ],
    correctOption: 'a',
  ),
  SortItOutCard(
    id: 'q3',
    prompt: 'Sales revenue',
    points: 10,
    options: [
      QuestionOption(id: 'a', text: 'Debit'),
      QuestionOption(id: 'b', text: 'Credit'),
    ],
    correctOption: 'b',
  ),
];

SortItOutCardReview _card(
  String q,
  String prompt, {
  required String chose,
  required String correct,
  required bool ok,
  bool timeout = false,
  required int ms,
  String? explanation,
}) => SortItOutCardReview(
  question: q,
  prompt: prompt,
  selectedOption: chose,
  correctOption: correct,
  isCorrect: ok,
  isTimeout: timeout,
  timeTakenMs: ms,
  basePoints: 0,
  speedBonus: 0,
  comboBonus: 0,
  pointsEarned: ok ? 14 : 0,
  explanation: explanation,
);

SortItOutResult _sort() => SortItOutResult(
  session: 's1',
  pairType: 'debit_credit',
  totalQuestions: 3,
  correctCount: 1,
  timeoutCount: 1,
  bestStreak: 1,
  accuracyPercentage: 33,
  finalScore: 24,
  coinsAwarded: 8,
  xpAwarded: 20,
  gemsAwarded: 0,
  scoreBreakdown: const {'base_points': 10, 'speed_bonus': 4, 'combo_bonus': 0},
  cardsReview: [
    _card(
      'q1',
      'Bank loan',
      chose: 'a',
      correct: 'b',
      ok: false,
      ms: 3200,
      explanation: 'A loan is owed to the bank, so it is a liability: credit.',
    ),
    _card(
      'q2',
      'Office equipment',
      chose: 'a',
      correct: 'a',
      ok: true,
      ms: 1900,
    ),
    _card(
      'q3',
      'Sales revenue',
      chose: 'timeout',
      correct: 'b',
      ok: false,
      timeout: true,
      ms: 10000,
    ),
  ],
);

final _shot = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  QuizResult result, {
  bool leveledUp = false,
  bool withProviders = true,
  int frames = 60,
}) => _pumpChild(
  tester,
  QuizResultView(
    result: result,
    leveledUp: leveledUp,
    onDone: () {},
    onPlayAgain: () {},
  ),
  withProviders: withProviders,
  frames: frames,
);

Future<void> _pumpChild(
  WidgetTester tester,
  Widget child, {
  bool withProviders = true,
  int frames = 60,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.create();
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final app = RepaintBoundary(
    key: _shot,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: GameScaffold(body: SafeArea(child: child)),
    ),
  );
  await tester.pumpWidget(
    withProviders
        ? ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              authControllerProvider.overrideWith(_SignedIn.new),
              dailyMissionDatasourceProvider.overrideWithValue(_Goals()),
              streakRewardsDatasourceProvider.overrideWithValue(_NoRewards()),
              walletDatasourceProvider.overrideWithValue(
                WalletMockDatasource(),
              ),
            ],
            child: app,
          )
        : app,
  );
  // Let the count-ups and entrance animations finish.
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary =
      tester.renderObject(find.byKey(_shot)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory(_outDir.isEmpty ? 'build/preview' : _outDir)
    ..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });

  testWidgets('summary: a good game', (tester) async {
    await _pump(tester, _result());
    await _save(tester, '1_summary_good');
  });

  testWidgets('progress screen', (tester) async {
    await _pump(tester, _result());
    await tester.tap(find.byKey(const Key('result_primary')));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, '2_progress');
  });

  testWidgets('coins in flight', (tester) async {
    // The flight starts at 1.1s and lasts 1.4s; look at about 60% of it.
    await _pump(tester, _result(), frames: 38);
    await _save(tester, '10_coins_flying');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('summary: a poor game', (tester) async {
    await _pump(tester, _result(correct: 2, points: 20, xp: 15, coins: 6));
    await _save(tester, '3_summary_poor');
  });

  testWidgets('review your answers', (tester) async {
    await _pump(
      tester,
      _result(
        correct: 6,
        answers: [
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          false,
        ],
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('answer_strip_tap')));
    await tester.tap(find.byKey(const Key('answer_strip_tap')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, '5_review');
  });

  testWidgets('match: summary and review', (tester) async {
    await _pumpChild(
      tester,
      MatchTheFollowingResultView(
        result: _match(),
        onDone: () {},
        onPlayAgain: () {},
      ),
    );
    await _save(tester, '6_match_summary');
    await tester.tap(find.byKey(const Key('answer_strip_tap')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, '7_match_review');
  });

  testWidgets('sort: summary and review', (tester) async {
    await _pumpChild(
      tester,
      SortItOutResultView(
        result: _sort(),
        cards: _sortCards,
        onDone: () {},
        onPlayAgain: () {},
      ),
    );
    await _save(tester, '8_sort_summary');
    await tester.tap(find.byKey(const Key('answer_strip_tap')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _save(tester, '9_sort_review');
  });

  testWidgets('summary: Sudden Death', (tester) async {
    await _pump(
      tester,
      _result(correct: 7, total: 8, endedEarly: true, points: 70),
    );
    await _save(tester, '4_summary_sudden_death');
  });
}
