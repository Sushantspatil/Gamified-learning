import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/match_the_following_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/screens/match_the_following_screen.dart';

class _FakeLocalStorage implements LocalStorageService {
  final Map<String, String> _map = {};

  @override
  String? getString(String key) => _map[key];

  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }
}

ApiClient _createApiClient(http.Client client) {
  return ApiClient(
    config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
    storage: _FakeLocalStorage(),
    httpClient: client,
  );
}

class _FakeAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const AppUser(
        id: 'test-user',
        email: 'test@skillverse.com',
        displayName: 'Tester',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Match the Following — DTOs & Serialization Contract', () {
    test('CreateSessionRequestDto serializes game_mode=match_the_following, question_count=3, and no custom timer', () {
      const dto = CreateSessionRequestDto(
        topic: 'accounting',
        gameMode: 'match_the_following',
        questionCount: 3,
      );

      final json = dto.toJson();
      expect(json['game_mode'], 'match_the_following');
      expect(json['question_count'], 3);
      expect(json['abandon_stale'], true);
      expect(json.containsKey('time_limit_per_question_sec'), false);
    });

    test('SessionCreatedResponseDto parses boards list and board time limit', () {
      final json = {
        'session': 'sess_mtf_100',
        'topic': 'accounting',
        'game_mode': 'match_the_following',
        'total_questions': 2,
        'time_limit_sec': 50,
        'time_limit_per_question_sec': 25,
        'boards': [
          {
            'question_code': 'mtf_acc_001',
            'prompt': 'Match accounts with their classifications',
            'time_limit_sec': 25,
            'left_items': [
              {'id': 'p1_l', 'text': 'Cash'},
              {'id': 'p2_l', 'text': 'Salary'},
            ],
            'right_items': [
              {'id': 'p2_r', 'text': 'Nominal Account'},
              {'id': 'p1_r', 'text': 'Real Account'},
            ],
            'solution_map': {
              'p1_l': 'p1_r',
              'p2_l': 'p2_r',
            },
            'hint': 'Think about asset vs expense',
            'explanation': 'Cash is an asset (real), Salary is expense (nominal).',
          },
        ],
      };

      final dto = SessionCreatedResponseDto.fromJson(json);
      expect(dto.session, 'sess_mtf_100');
      expect(dto.gameMode, 'match_the_following');
      expect(dto.totalQuestions, 2);
      expect(dto.timeLimitPerQuestionSec, 25);
      expect(dto.boards?.length, 1);

      final board = dto.boards![0];
      expect(board.questionCode, 'mtf_acc_001');
      expect(board.prompt, 'Match accounts with their classifications');
      expect(board.timeLimitSec, 25);
      expect(board.leftItems.length, 2);
      expect(board.leftItems[0].id, 'p1_l');
      expect(board.leftItems[0].text, 'Cash');
      expect(board.rightItems.length, 2);
      // Verify right-item order is preserved from backend without client re-shuffling!
      expect(board.rightItems[0].id, 'p2_r');
      expect(board.rightItems[0].text, 'Nominal Account');
      expect(board.rightItems[1].id, 'p1_r');
      expect(board.solutionMap['p1_l'], 'p1_r');
      expect(board.solutionMap['p2_l'], 'p2_r');
      expect(board.hint, 'Think about asset vs expense');
      expect(board.explanation, 'Cash is an asset (real), Salary is expense (nominal).');
    });

    test('MatchBoardAnswerSubmissionDto serializes board matches and timeout', () {
      const submission = MatchBoardAnswerSubmissionDto(
        questionCode: 'mtf_acc_001',
        matches: {
          'p1_l': 'p1_r',
          'p2_l': 'p2_r',
        },
        mistakes: 1,
        timeTakenMs: 14200,
        isTimeout: false,
      );

      final json = submission.toJson();
      expect(json['question_code'], 'mtf_acc_001');
      expect(json['matches']['p1_l'], 'p1_r');
      expect(json['matches']['p2_l'], 'p2_r');
      expect(json['mistakes'], 1);
      expect(json['time_taken_ms'], 14200);
      expect(json.containsKey('is_timeout'), false);

      const timeoutSub = MatchBoardAnswerSubmissionDto(
        questionCode: 'mtf_acc_002',
        matches: {'p3_l': 'p3_r'},
        mistakes: 2,
        timeTakenMs: 25000,
        isTimeout: true,
      );
      final timeoutJson = timeoutSub.toJson();
      expect(timeoutJson['is_timeout'], true);
    });

    test('CompleteMatchTheFollowingRequestDto serializes session and boards list', () {
      const requestDto = CompleteMatchTheFollowingRequestDto(
        session: 'sess_batch_1',
        boards: [
          MatchBoardAnswerSubmissionDto(
            questionCode: 'mtf_acc_001',
            matches: {'p1_l': 'p1_r'},
            mistakes: 0,
            timeTakenMs: 12000,
          ),
        ],
      );

      final json = requestDto.toJson();
      expect(json['session'], 'sess_batch_1');
      final boardsList = json['boards'] as List<dynamic>;
      expect(boardsList.length, 1);
      expect(boardsList[0]['question_code'], 'mtf_acc_001');
    });

    test('CompleteMatchTheFollowingResponseDto parses rich results and score breakdown', () {
      final json = {
        'session': 'sess_batch_1',
        'total_boards': 3,
        'cleared_boards': 2,
        'total_pairs_matched': 7,
        'total_pairs_count': 8,
        'total_mistakes': 1,
        'accuracy_percentage': 87.5,
        'final_score': 82,
        'coins_awarded': 35,
        'xp_awarded': 70,
        'gems_awarded': 1,
        'score_breakdown': {
          'base_points': 70,
          'flawless_bonus': 10,
          'speed_bonus': 4,
          'mistake_penalty': 2,
          'final_score': 82,
        },
        'coin_breakdown': {
          'completion_coins': 20,
          'correct_answer_coins': 15,
        },
        'xp_breakdown': {
          'completion_xp': 40,
          'correct_answer_xp': 30,
        },
        'level_up_reward': {
          'coins': 50,
          'gems': 1,
        },
        'level': {
          'current': 3,
          'did_level_up': true,
          'experience': 210,
          'next_level_exp': 300,
        },
        'streak': {
          'current_streak': 5,
          'today_completed': true,
        },
        'boards_review': [
          {
            'question_code': 'mtf_acc_001',
            'prompt': 'Match accounts',
            'pairs_matched': 4,
            'total_pairs': 4,
            'mistakes': 0,
            'time_taken_ms': 18000,
            'is_flawless': true,
            'is_timeout': false,
            'base_points': 40,
            'flawless_bonus': 10,
            'speed_bonus': 7,
            'mistake_penalty': 0,
            'total_board_score': 57,
            'explanation': 'All accounts correctly classified.',
          },
        ],
      };

      final dto = CompleteMatchTheFollowingResponseDto.fromJson(json);
      expect(dto.session, 'sess_batch_1');
      expect(dto.totalBoards, 3);
      expect(dto.clearedBoards, 2);
      expect(dto.totalPairsMatched, 7);
      expect(dto.totalPairsCount, 8);
      expect(dto.totalMistakes, 1);
      expect(dto.accuracyPercentage, 87.5);
      expect(dto.finalScore, 82);
      expect(dto.coinsAwarded, 35);
      expect(dto.xpAwarded, 70);
      expect(dto.gemsAwarded, 1);
      expect(dto.scoreBreakdown['base_points'], 70);
      expect(dto.scoreBreakdown['mistake_penalty'], 2);
      expect(dto.level?.didLevelUp, true);
      expect(dto.level?.current, 3);
      expect(dto.levelUpReward?.coins, 50);
      expect(dto.boardsReview.length, 1);

      final review = dto.boardsReview[0];
      expect(review.isFlawless, true);
      expect(review.totalBoardScore, 57);
      expect(review.speedBonus, 7);
    });
  });

  group('Match the Following — Remote Datasource Integration', () {
    test('createSession sends game_mode=match_the_following and populates activeMatchBoards', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/quiz/sessions/create') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['topic'], 'accounting');
          expect(body['game_mode'], 'match_the_following');
          expect(body['question_count'], 3);

          return http.Response(
            jsonEncode({
              'session': 'sess_remote_mtf',
              'topic': 'accounting',
              'game_mode': 'match_the_following',
              'total_questions': 1,
              'time_limit_sec': 25,
              'time_limit_per_question_sec': 25,
              'boards': [
                {
                  'question_code': 'mtf_001',
                  'prompt': 'Match terminology',
                  'time_limit_sec': 25,
                  'left_items': [
                    {'id': 'l1', 'text': 'Asset'},
                    {'id': 'l2', 'text': 'Liability'},
                  ],
                  'right_items': [
                    {'id': 'r2', 'text': 'Debt'},
                    {'id': 'r1', 'text': 'Property'},
                  ],
                  'solution_map': {
                    'l1': 'r1',
                    'l2': 'r2',
                  },
                },
              ],
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = _createApiClient(mockClient);
      final ds = QuizRemoteDatasource(apiClient: apiClient);

      final sessionId = await ds.createSession(
        topicId: 'accounting',
        gameMode: 'match_the_following',
        questionCount: 3,
      );

      expect(sessionId, 'sess_remote_mtf');
      expect(ds.activeMatchBoards?.length, 1);
      expect(ds.activeMatchBoards?[0].questionCode, 'mtf_001');
      expect(ds.activeMatchBoards?[0].solutionMap['l1'], 'r1');
    });

    test('completeMatchTheFollowing posts batch answers to /api/v1/quiz/match-the-following/complete', () async {
      var endpointCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/quiz/match-the-following/complete') {
          endpointCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session'], 'sess_remote_mtf');
          final boards = body['boards'] as List<dynamic>;
          expect(boards.length, 1);
          expect(boards[0]['question_code'], 'mtf_001');
          expect(boards[0]['matches']['l1'], 'r1');
          expect(boards[0]['mistakes'], 0);
          expect(boards[0]['time_taken_ms'], 12500);

          return http.Response(
            jsonEncode({
              'session': 'sess_remote_mtf',
              'total_boards': 1,
              'cleared_boards': 1,
              'total_pairs_matched': 2,
              'total_pairs_count': 2,
              'total_mistakes': 0,
              'accuracy_percentage': 100.0,
              'final_score': 32,
              'coins_awarded': 20,
              'xp_awarded': 40,
              'gems_awarded': 3,
              'score_breakdown': {
                'base_points': 20,
                'flawless_bonus': 10,
                'speed_bonus': 2,
                'mistake_penalty': 0,
                'final_score': 32,
              },
              'boards_review': [],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = _createApiClient(mockClient);
      final ds = QuizRemoteDatasource(apiClient: apiClient);

      final response = await ds.completeMatchTheFollowing(
        session: 'sess_remote_mtf',
        boards: const [
          MatchBoardAnswerSubmissionDto(
            questionCode: 'mtf_001',
            matches: {'l1': 'r1'},
            mistakes: 0,
            timeTakenMs: 12500,
          ),
        ],
      );

      expect(endpointCalled, true);
      expect(response.finalScore, 32);
      expect(response.accuracyPercentage, 100.0);
    });
  });

  group('Match the Following — Controller Gameplay & Logic', () {
    late ProviderContainer container;
    late ProviderSubscription subscription;
    var completeCallCount = 0;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/quiz/sessions/create') {
        return http.Response(
          jsonEncode({
            'session': 'controller_mtf_sess_1',
            'topic': 'accounting',
            'game_mode': 'match_the_following',
            'total_questions': 2,
            'time_limit_sec': 50,
            'time_limit_per_question_sec': 25,
            'boards': [
              {
                'question_code': 'board_1',
                'prompt': 'Board 1: Classify',
                'time_limit_sec': 25,
                'left_items': [
                  {'id': 'b1_l1', 'text': 'Cash'},
                  {'id': 'b1_l2', 'text': 'Rent'},
                ],
                'right_items': [
                  {'id': 'b1_r2', 'text': 'Nominal'},
                  {'id': 'b1_r1', 'text': 'Real'},
                ],
                'solution_map': {
                  'b1_l1': 'b1_r1',
                  'b1_l2': 'b1_r2',
                },
                'hint': 'Cash is an asset.',
              },
              {
                'question_code': 'board_2',
                'prompt': 'Board 2: Financial statements',
                'time_limit_sec': 25,
                'left_items': [
                  {'id': 'b2_l1', 'text': 'Balance Sheet'},
                  {'id': 'b2_l2', 'text': 'Income Statement'},
                ],
                'right_items': [
                  {'id': 'b2_r2', 'text': 'Profit & Loss'},
                  {'id': 'b2_r1', 'text': 'Financial Position'},
                ],
                'solution_map': {
                  'b2_l1': 'b2_r1',
                  'b2_l2': 'b2_r2',
                },
              },
            ],
          }),
          201,
        );
      }

      if (request.url.path == '/api/v1/quiz/match-the-following/complete') {
        completeCallCount++;
        return http.Response(
          jsonEncode({
            'session': 'controller_mtf_sess_1',
            'total_boards': 2,
            'cleared_boards': 2,
            'total_pairs_matched': 4,
            'total_pairs_count': 4,
            'total_mistakes': 1,
            'accuracy_percentage': 100.0,
            'final_score': 68,
            'coins_awarded': 30,
            'xp_awarded': 60,
            'gems_awarded': 3,
            'score_breakdown': {
              'base_points': 40,
              'flawless_bonus': 10,
              'speed_bonus': 20,
              'mistake_penalty': 2,
              'final_score': 68,
            },
            'boards_review': [
              {
                'question_code': 'board_1',
                'prompt': 'Board 1: Classify',
                'pairs_matched': 2,
                'total_pairs': 2,
                'mistakes': 1,
                'time_taken_ms': 10000,
                'is_flawless': false,
                'is_timeout': false,
                'base_points': 20,
                'flawless_bonus': 0,
                'speed_bonus': 15,
                'mistake_penalty': 2,
                'total_board_score': 33,
                'explanation': 'Correct classification.',
              },
              {
                'question_code': 'board_2',
                'prompt': 'Board 2: Financial statements',
                'pairs_matched': 2,
                'total_pairs': 2,
                'mistakes': 0,
                'time_taken_ms': 8000,
                'is_flawless': true,
                'is_timeout': false,
                'base_points': 20,
                'flawless_bonus': 10,
                'speed_bonus': 17,
                'mistake_penalty': 0,
                'total_board_score': 47,
                'explanation': 'Flawless board.',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    const request = QuizSessionRequest(
      topicId: 'accounting',
      quizType: QuestionType.matchTheFollowing,
    );

    setUp(() {
      completeCallCount = 0;
      final apiClient = _createApiClient(mockClient);
      final ds = QuizRemoteDatasource(apiClient: apiClient);

      container = ProviderContainer(
        overrides: [
          quizDatasourceProvider.overrideWithValue(ds),
          authControllerProvider.overrideWith(_FakeAuth.new),
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        ],
      );
      subscription = container.listen(
        matchTheFollowingControllerProvider(request),
        (_, _) {},
      );
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('initializes with upfront boards, solution_map, and 25-second timer', () async {
      final state = await container.read(matchTheFollowingControllerProvider(request).future);
      expect(state.sessionId, 'controller_mtf_sess_1');
      expect(state.boards.length, 2);
      expect(state.currentBoardIndex, 0);
      expect(state.currentBoard?.questionCode, 'board_1');
      expect(state.currentBoard?.timeLimitSec, 25);
      expect(state.currentBoard?.solutionMap['b1_l1'], 'b1_r1');
      expect(state.boardResolved, false);
      expect(state.isCompleting, false);
    });

    test('correct and wrong match validation, mistake counting, and board auto-clear', () async {
      await container.read(matchTheFollowingControllerProvider(request).future);
      final controller = container.read(matchTheFollowingControllerProvider(request).notifier);

      // 1. Select Left 1 (Cash)
      controller.selectLeft('b1_l1');
      var state = container.read(matchTheFollowingControllerProvider(request)).value!;
      expect(state.selectedLeftId, 'b1_l1');

      // 2. Select Wrong Right (Nominal -> b1_r2)
      await controller.selectRight('b1_r2');
      state = container.read(matchTheFollowingControllerProvider(request)).value!;
      expect(state.mistakes, 1);
      expect(state.correctMatches.isEmpty, true);
      expect(state.selectedLeftId, null); // selection cleared for retry
      expect(completeCallCount, 0); // NO network call per attempt!

      // 3. Select Left 1 again (Cash) and Correct Right (Real -> b1_r1)
      controller.selectLeft('b1_l1');
      await controller.selectRight('b1_r1');
      state = container.read(matchTheFollowingControllerProvider(request)).value!;
      expect(state.correctMatches['b1_l1'], 'b1_r1');
      expect(state.mistakes, 1); // mistake didn't increase on correct match
      expect(state.boardResolved, false); // 1 pair remaining

      // 4. Select Left 2 (Rent) and Correct Right (Nominal -> b1_r2)
      controller.selectLeft('b1_l2');
      await controller.selectRight('b1_r2');

      // Board 1 is cleared! Wait for board transition delay
      await Future<void>.delayed(const Duration(milliseconds: 350));
      state = container.read(matchTheFollowingControllerProvider(request)).value!;

      // Board 1 submission recorded
      expect(state.boardSubmissions.length, 1);
      expect(state.boardSubmissions[0].questionCode, 'board_1');
      expect(state.boardSubmissions[0].matches.length, 2);
      expect(state.boardSubmissions[0].mistakes, 1);
      expect(state.boardSubmissions[0].isTimeout, false);

      // Board 2 is now active!
      expect(state.currentBoardIndex, 1);
      expect(state.currentBoard?.questionCode, 'board_2');
      expect(state.correctMatches.isEmpty, true);
      expect(state.mistakes, 0);

      // 5. Board 2: Match both correctly
      controller.selectLeft('b2_l1');
      await controller.selectRight('b2_r1');
      controller.selectLeft('b2_l2');
      await controller.selectRight('b2_r2');

      await Future<void>.delayed(const Duration(milliseconds: 350));
      state = container.read(matchTheFollowingControllerProvider(request)).value!;

      // Final board triggers single-flight batch completion!
      expect(completeCallCount, 1);
      expect(state.result != null, true);
      expect(state.result?.finalScore, 68);
      expect(state.result?.totalMistakes, 1);
      expect(state.result?.boardsReview.length, 2);
    });

    test('timeout preserves partial matches and auto-advances', () async {
      await container.read(matchTheFollowingControllerProvider(request).future);
      final controller = container.read(matchTheFollowingControllerProvider(request).notifier);

      // Match 1 pair correctly on Board 1
      controller.selectLeft('b1_l1');
      await controller.selectRight('b1_r1');

      // Trigger timeout on board 1
      await controller.handleTimeout();

      await Future<void>.delayed(const Duration(milliseconds: 350));
      final state = container.read(matchTheFollowingControllerProvider(request)).value!;

      // Board 1 submission recorded with is_timeout=true and partial matches preserved
      expect(state.boardSubmissions.length, 1);
      expect(state.boardSubmissions[0].isTimeout, true);
      expect(state.boardSubmissions[0].matches.length, 1);
      expect(state.boardSubmissions[0].matches['b1_l1'], 'b1_r1');

      // Auto-advanced to board 2
      expect(state.currentBoardIndex, 1);
    });
  });

  group('Match the Following — Screen & Interactive UI', () {
    late ProviderContainer container;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/quiz/sessions/create') {
        return http.Response(
          jsonEncode({
            'session': 'ui_mtf_sess',
            'topic': 'accounting',
            'game_mode': 'match_the_following',
            'total_questions': 1,
            'time_limit_sec': 25,
            'time_limit_per_question_sec': 25,
            'boards': [
              {
                'question_code': 'ui_board_1',
                'prompt': 'Match accounts with classifications',
                'time_limit_sec': 25,
                'left_items': [
                  {'id': 'ui_l1', 'text': 'Cash A/C'},
                  {'id': 'ui_l2', 'text': 'Wages A/C'},
                ],
                'right_items': [
                  {'id': 'ui_r2', 'text': 'Nominal Account'},
                  {'id': 'ui_r1', 'text': 'Real Account'},
                ],
                'solution_map': {
                  'ui_l1': 'ui_r1',
                  'ui_l2': 'ui_r2',
                },
                'hint': 'Cash is an asset.',
              },
            ],
          }),
          201,
        );
      }

      if (request.url.path == '/api/v1/quiz/match-the-following/complete') {
        return http.Response(
          jsonEncode({
            'session': 'ui_mtf_sess',
            'total_boards': 1,
            'cleared_boards': 1,
            'total_pairs_matched': 2,
            'total_pairs_count': 2,
            'total_mistakes': 0,
            'accuracy_percentage': 100.0,
            'final_score': 35,
            'coins_awarded': 20,
            'xp_awarded': 45,
            'gems_awarded': 3,
            'score_breakdown': {
              'base_points': 20,
              'flawless_bonus': 10,
              'speed_bonus': 5,
              'mistake_penalty': 0,
              'final_score': 35,
            },
            'boards_review': [
              {
                'question_code': 'ui_board_1',
                'prompt': 'Match accounts with classifications',
                'pairs_matched': 2,
                'total_pairs': 2,
                'mistakes': 0,
                'time_taken_ms': 10000,
                'is_flawless': true,
                'is_timeout': false,
                'base_points': 20,
                'flawless_bonus': 10,
                'speed_bonus': 5,
                'mistake_penalty': 0,
                'total_board_score': 35,
                'explanation': 'Perfect classifications.',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    setUp(() {
      final apiClient = _createApiClient(mockClient);
      final ds = QuizRemoteDatasource(apiClient: apiClient);

      container = ProviderContainer(
        overrides: [
          quizDatasourceProvider.overrideWithValue(ds),
          authControllerProvider.overrideWith(_FakeAuth.new),
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders board counter, prompt, cards, handles pair taps, and displays results', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MatchTheFollowingScreen(topicId: 'accounting'),
          ),
        ),
      );

      // Wait for session create
      await tester.pumpAndSettle();

      // Verify header & dynamic labels (restored approved MatchTheFollowingView)
      expect(find.text('Match accounts with classifications'), findsOneWidget);
      expect(find.text('Cash A/C'), findsOneWidget);
      expect(find.text('Wages A/C'), findsOneWidget);
      expect(find.text('Nominal Account'), findsOneWidget);
      expect(find.text('Real Account'), findsOneWidget);

      // Tap Left 1: Cash A/C
      await tester.tap(find.byKey(const Key('match-left-ui_l1')));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Right 1: Real Account (correct match)
      await tester.tap(find.byKey(const Key('match-right-ui_r1')));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Left 2: Wages A/C
      await tester.tap(find.byKey(const Key('match-left-ui_l2')));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Right 2: Nominal Account (correct match, clears board!)
      await tester.tap(find.byKey(const Key('match-right-ui_r2')));
      // Board advance delay is 320ms, then completion API call completes
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Results screen appears with authoritative values!
      expect(find.text('Match the Following — Results'), findsOneWidget);
      expect(find.text('Official Score'), findsOneWidget);
      expect(find.text('35'), findsAtLeast(1));
      expect(find.text('+45 XP'), findsOneWidget);
      expect(find.text('+20 Coins'), findsOneWidget);
      expect(find.text('Score Breakdown'), findsOneWidget);
      expect(find.text('Base Points'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Flawless Bonus'), findsOneWidget);
      expect(find.text('Speed Bonus'), findsOneWidget);
      expect(find.text('Board review'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
