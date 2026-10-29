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
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/domain/entities/sort_it_out_models.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sort_it_out_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/screens/sort_it_out_screen.dart';

class _FakeAuth extends AuthController {
  @override
  Future<AppUser?> build() async => const AppUser(
        id: 'test-user',
        email: 'test@skillverse.com',
        displayName: 'Tester',
      );
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sort It Out — DTOs & Serialization Contract', () {
    test('CreateSessionRequestDto serializes game_mode=sort_it_out, pair_type, and time_limit_per_question_sec', () {
      const dto = CreateSessionRequestDto(
        topic: 'accounting',
        gameMode: 'sort_it_out',
        pairType: 'credit_debit',
        questionCount: 10,
        timeLimitPerQuestionSec: 7,
      );

      final json = dto.toJson();
      expect(json['game_mode'], 'sort_it_out');
      expect(json['pair_type'], 'credit_debit');
      expect(json['question_count'], 10);
      expect(json['time_limit_per_question_sec'], 7);
      expect(json['abandon_stale'], true);
    });

    test('SessionCreatedResponseDto parses pair_type and time_limit_per_question_sec', () {
      final json = {
        'session': 'sess_123',
        'topic': 'accounting',
        'game_mode': 'sort_it_out',
        'pair_type': 'credit_debit',
        'total_questions': 5,
        'time_limit_sec': 35,
        'time_limit_per_question_sec': 7,
        'questions': [
          {
            'question': 'q1',
            'prompt': 'Accounts Payable',
            'points': 10,
            'time_limit_sec': 7,
            'options': [
              {'option': 'a', 'text': 'Debit'},
              {'option': 'b', 'text': 'Credit'},
            ],
            'correct_option': 'b',
            'pair_type': 'credit_debit',
            'explanation': 'Accounts Payable is a liability, normal credit balance.',
          }
        ],
      };

      final dto = SessionCreatedResponseDto.fromJson(json);
      expect(dto.session, 'sess_123');
      expect(dto.gameMode, 'sort_it_out');
      expect(dto.pairType, 'credit_debit');
      expect(dto.totalQuestions, 5);
      expect(dto.timeLimitPerQuestionSec, 7);
      expect(dto.questions.length, 1);

      final qDto = QuestionDto.fromJson(dto.questions.first);
      expect(qDto.question, 'q1');
      expect(qDto.prompt, 'Accounts Payable');
      expect(qDto.correctOption, 'b');
      expect(qDto.pairType, 'credit_debit');
      expect(qDto.explanation, contains('Accounts Payable is a liability'));
      expect(qDto.options.length, 2);
      expect(qDto.options[0].text, 'Debit');
      expect(qDto.options[1].text, 'Credit');
    });

    test('SortItOutAnswerSubmissionDto serializes choice and timeout correctly', () {
      const normalAnswer = SortItOutAnswerSubmissionDto(
        question: 'q1',
        option: 'a',
        timeTakenMs: 1450,
      );
      final normalJson = normalAnswer.toJson();
      expect(normalJson['question'], 'q1');
      expect(normalJson['option'], 'a');
      expect(normalJson['time_taken_ms'], 1450);
      expect(normalJson.containsKey('is_timeout'), false);

      const timeoutAnswer = SortItOutAnswerSubmissionDto(
        question: 'q2',
        option: 'timeout',
        timeTakenMs: 7000,
        isTimeout: true,
      );
      final timeoutJson = timeoutAnswer.toJson();
      expect(timeoutJson['question'], 'q2');
      expect(timeoutJson['option'], 'timeout');
      expect(timeoutJson['time_taken_ms'], 7000);
      expect(timeoutJson['is_timeout'], true);
    });

    test('CompleteSortItOutRequestDto serializes session and batch answers', () {
      const request = CompleteSortItOutRequestDto(
        session: 'sess_999',
        answers: [
          SortItOutAnswerSubmissionDto(
            question: 'q1',
            option: 'a',
            timeTakenMs: 1200,
          ),
          SortItOutAnswerSubmissionDto(
            question: 'q2',
            option: 'timeout',
            timeTakenMs: 7000,
            isTimeout: true,
          ),
        ],
      );

      final json = request.toJson();
      expect(json['session'], 'sess_999');
      final answers = json['answers'] as List<dynamic>;
      expect(answers.length, 2);
      expect(answers[0]['option'], 'a');
      expect(answers[1]['is_timeout'], true);
    });

    test('CompleteSortItOutResponseDto parses score breakdown, level up, and card reviews', () {
      final json = {
        'session': 'sess_999',
        'pair_type': 'credit_debit',
        'total_questions': 2,
        'correct_count': 1,
        'timeout_count': 1,
        'best_streak': 1,
        'accuracy_percentage': 50.0,
        'final_score': 15,
        'coins_awarded': 10,
        'xp_awarded': 25,
        'gems_awarded': 0,
        'score_breakdown': {
          'base_points': 10,
          'speed_bonus': 5,
          'combo_bonus': 0,
          'final_score': 15,
        },
        'level_up_reward': {'xp': 50, 'coins': 20, 'gems': 1},
        'level': {
          'current': 2,
          'did_level_up': true,
          'experience': 120,
          'next_level_exp': 200,
        },
        'streak': {'current_streak': 2, 'today_completed': true},
        'cards_review': [
          {
            'question': 'q1',
            'prompt': 'Cash Account',
            'selected_option': 'a',
            'correct_option': 'a',
            'is_correct': true,
            'is_timeout': false,
            'time_taken_ms': 1200,
            'base_points': 10,
            'speed_bonus': 5,
            'combo_bonus': 0,
            'points_earned': 15,
            'explanation': 'Cash has a normal debit balance.',
          },
          {
            'question': 'q2',
            'prompt': 'Accounts Payable',
            'selected_option': 'timeout',
            'correct_option': 'b',
            'is_correct': false,
            'is_timeout': true,
            'time_taken_ms': 7000,
            'base_points': 0,
            'speed_bonus': 0,
            'combo_bonus': 0,
            'points_earned': 0,
            'explanation': 'Accounts Payable is a liability.',
          },
        ],
      };

      final dto = CompleteSortItOutResponseDto.fromJson(json);
      expect(dto.session, 'sess_999');
      expect(dto.finalScore, 15);
      expect(dto.scoreBreakdown['base_points'], 10);
      expect(dto.scoreBreakdown['speed_bonus'], 5);
      expect(dto.level?.didLevelUp, true);
      expect(dto.cardsReview.length, 2);
      expect(dto.cardsReview[0].isCorrect, true);
      expect(dto.cardsReview[1].isTimeout, true);
      expect(dto.cardsReview[1].explanation, contains('Accounts Payable is a liability'));

      final result = SortItOutResult.fromDto(dto);
      expect(result.basePoints, 10);
      expect(result.speedBonus, 5);
      expect(result.comboBonus, 0);
      expect(result.didLevelUp, true);
      expect(result.cardsReview[1].isTimeout, true);
    });
  });

  group('Sort It Out — Remote Datasource Integration', () {
    test('createSession sends game_mode=sort_it_out and populates activeSortItOutCards', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/quiz/sessions/create') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['game_mode'], 'sort_it_out');
          expect(body['topic'], 'accounts');

          return http.Response(
            jsonEncode({
              'session': 'sess_remote_1',
              'topic': 'accounting',
              'game_mode': 'sort_it_out',
              'pair_type': 'credit_debit',
              'total_questions': 2,
              'time_limit_sec': 14,
              'time_limit_per_question_sec': 7,
              'questions': [
                {
                  'question': 'sort_1',
                  'prompt': 'Building A/C',
                  'points': 10,
                  'options': [
                    {'option': 'a', 'text': 'Debit'},
                    {'option': 'b', 'text': 'Credit'},
                  ],
                  'correct_option': 'a',
                  'pair_type': 'credit_debit',
                  'explanation': 'Building is an asset with debit balance.',
                },
                {
                  'question': 'sort_2',
                  'prompt': 'Capital A/C',
                  'points': 10,
                  'options': [
                    {'option': 'a', 'text': 'Debit'},
                    {'option': 'b', 'text': 'Credit'},
                  ],
                  'correct_option': 'b',
                  'pair_type': 'credit_debit',
                  'explanation': 'Capital is equity with credit balance.',
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
        gameMode: 'sort_it_out',
      );

      expect(sessionId, 'sess_remote_1');
      expect(ds.activePairType, 'credit_debit');
      expect(ds.activeTimeLimitPerQuestionSec, 7);
      expect(ds.activeSortItOutCards?.length, 2);
      expect(ds.activeSortItOutCards?[0].id, 'sort_1');
      expect(ds.activeSortItOutCards?[0].correctOption, 'a');
      expect(ds.activeSortItOutCards?[1].id, 'sort_2');
      expect(ds.activeSortItOutCards?[1].correctOption, 'b');
    });

    test('completeSortItOut posts to /api/v1/quiz/sort-it-out/complete with session and answers', () async {
      var endpointCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/quiz/sort-it-out/complete') {
          endpointCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session'], 'sess_remote_1');
          final answers = body['answers'] as List<dynamic>;
          expect(answers.length, 2);
          expect(answers[0]['question'], 'sort_1');
          expect(answers[0]['option'], 'a');
          expect(answers[0]['time_taken_ms'], 1500);

          return http.Response(
            jsonEncode({
              'session': 'sess_remote_1',
              'pair_type': 'credit_debit',
              'total_questions': 2,
              'correct_count': 2,
              'timeout_count': 0,
              'best_streak': 2,
              'accuracy_percentage': 100.0,
              'final_score': 30,
              'coins_awarded': 15,
              'xp_awarded': 45,
              'gems_awarded': 2,
              'score_breakdown': {
                'base_points': 20,
                'speed_bonus': 10,
                'combo_bonus': 0,
                'final_score': 30,
              },
              'level': {
                'current': 1,
                'did_level_up': false,
                'experience': 45,
                'next_level_exp': 100,
              },
              'cards_review': [],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = _createApiClient(mockClient);
      final ds = QuizRemoteDatasource(apiClient: apiClient);

      final response = await ds.completeSortItOut(
        session: 'sess_remote_1',
        answers: const [
          SortItOutAnswerSubmissionDto(
            question: 'sort_1',
            option: 'a',
            timeTakenMs: 1500,
          ),
          SortItOutAnswerSubmissionDto(
            question: 'sort_2',
            option: 'b',
            timeTakenMs: 1800,
          ),
        ],
      );

      expect(endpointCalled, true);
      expect(response.session, 'sess_remote_1');
      expect(response.finalScore, 30);
      expect(response.correctCount, 2);
    });
  });

  group('Sort It Out — Controller Gameplay & Logic', () {
    late ProviderContainer container;
    var completeCallCount = 0;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/quiz/sessions/create') {
        return http.Response(
          jsonEncode({
            'session': 'controller_sess_1',
            'topic': 'accounting',
            'game_mode': 'sort_it_out',
            'pair_type': 'credit_debit',
            'total_questions': 2,
            'time_limit_sec': 14,
            'time_limit_per_question_sec': 7,
            'questions': [
              {
                'question': 'c_q1',
                'prompt': 'Wages Expense',
                'points': 10,
                'options': [
                  {'option': 'a', 'text': 'Debit'},
                  {'option': 'b', 'text': 'Credit'},
                ],
                'correct_option': 'a',
                'pair_type': 'credit_debit',
                'explanation': 'Wages are expenses (debit).',
              },
              {
                'question': 'c_q2',
                'prompt': 'Commission Received',
                'points': 10,
                'options': [
                  {'option': 'a', 'text': 'Debit'},
                  {'option': 'b', 'text': 'Credit'},
                ],
                'correct_option': 'b',
                'pair_type': 'credit_debit',
                'explanation': 'Commission received is revenue (credit).',
              },
            ],
          }),
          201,
        );
      }
      if (request.url.path == '/api/v1/quiz/sort-it-out/complete') {
        completeCallCount++;
        return http.Response(
          jsonEncode({
            'session': 'controller_sess_1',
            'pair_type': 'credit_debit',
            'total_questions': 2,
            'correct_count': 2,
            'timeout_count': 0,
            'best_streak': 2,
            'accuracy_percentage': 100.0,
            'final_score': 30,
            'coins_awarded': 15,
            'xp_awarded': 45,
            'gems_awarded': 2,
            'score_breakdown': {
              'base_points': 20,
              'speed_bonus': 10,
              'combo_bonus': 0,
              'final_score': 30,
            },
            'cards_review': [
              {
                'question': 'c_q1',
                'prompt': 'Wages Expense',
                'selected_option': 'a',
                'correct_option': 'a',
                'is_correct': true,
                'is_timeout': false,
                'time_taken_ms': 1100,
                'base_points': 10,
                'speed_bonus': 5,
                'combo_bonus': 0,
                'points_earned': 15,
                'explanation': 'Wages are expenses (debit).',
              },
              {
                'question': 'c_q2',
                'prompt': 'Commission Received',
                'selected_option': 'b',
                'correct_option': 'b',
                'is_correct': true,
                'is_timeout': false,
                'time_taken_ms': 1200,
                'base_points': 10,
                'speed_bonus': 5,
                'combo_bonus': 0,
                'points_earned': 15,
                'explanation': 'Commission received is revenue (credit).',
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
      quizType: QuestionType.sortItRight,
    );

    late ProviderSubscription subscription;

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
        sortItOutControllerProvider(request),
        (_, _) {},
      );
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('initializes with upfront deck, correct option, and per-card timer', () async {
      final state = await container.read(sortItOutControllerProvider(request).future);
      expect(state.sessionId, 'controller_sess_1');
      expect(state.pairType, 'credit_debit');
      expect(state.cards.length, 2);
      expect(state.currentIndex, 0);
      expect(state.currentCard?.prompt, 'Wages Expense');
      expect(state.currentCard?.correctOption, 'a');
      expect(state.perQuestionTimeLimitSec, 7);
      expect(state.cardResolved, false);
      expect(state.isCompleting, false);
    });

    test('swipe left and right records exactly one answer per card and submits batch on deck end', () async {
      await container.read(sortItOutControllerProvider(request).future);
      final controller = container.read(sortItOutControllerProvider(request).notifier);

      // 1. First card: Wages Expense -> submit 'a' (correct)
      await controller.submitOption('a');

      // Verify no per-card evaluate HTTP call
      expect(completeCallCount, 0);

      // Verify next card is active
      var state = container.read(sortItOutControllerProvider(request)).value!;
      expect(state.currentIndex, 1);
      expect(state.currentCard?.prompt, 'Commission Received');
      expect(state.currentCombo, 1);
      expect(state.answers.length, 1);
      expect(state.answers[0].option, 'a');
      expect(state.answers[0].isTimeout, false);

      // 2. Second card: Commission Received -> submit 'b' (correct)
      await controller.submitOption('b');

      // Final card completes the deck -> batch endpoint called exactly once!
      state = container.read(sortItOutControllerProvider(request)).value!;
      expect(completeCallCount, 1);
      expect(state.result != null, true);
      expect(state.result?.finalScore, 30);
      expect(state.result?.correctCount, 2);
      expect(state.result?.cardsReview.length, 2);
    });

    test('input locking prevents multiple swipes or race with timer from duplicating answer', () async {
      await container.read(sortItOutControllerProvider(request).future);
      final controller = container.read(sortItOutControllerProvider(request).notifier);

      // Fire option 'a' and immediately attempt timeout & second swipe
      final future1 = controller.submitOption('a');
      final future2 = controller.submitOption('b');
      final future3 = controller.handleTimeout();

      await Future.wait([future1, future2, future3]);

      final state = container.read(sortItOutControllerProvider(request)).value!;
      // Exactly 1 answer recorded for card 1
      expect(state.answers.where((a) => a.question == 'c_q1').length, 1);
    });

    test('timeout records option=timeout, resets combo streak, and auto-advances', () async {
      await container.read(sortItOutControllerProvider(request).future);
      final controller = container.read(sortItOutControllerProvider(request).notifier);

      // Force timeout on card 1
      await controller.handleTimeout();

      final state = container.read(sortItOutControllerProvider(request)).value!;
      expect(state.currentCombo, 0);
      expect(state.answers.length, 1);
      expect(state.answers[0].isTimeout, true);
      expect(state.answers[0].option, 'timeout');
      expect(state.currentIndex, 1);
    });
  });

  group('Sort It Out — Screen & Interactive UI', () {
    late ProviderContainer container;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/quiz/sessions/create') {
        return http.Response(
          jsonEncode({
            'session': 'ui_sess_1',
            'topic': 'accounting',
            'game_mode': 'sort_it_out',
            'pair_type': 'credit_debit',
            'total_questions': 2,
            'time_limit_sec': 14,
            'time_limit_per_question_sec': 7,
            'questions': [
              {
                'question': 'ui_q1',
                'prompt': 'Bank Loan',
                'points': 10,
                'options': [
                  {'option': 'a', 'text': 'Debit'},
                  {'option': 'b', 'text': 'Credit'},
                ],
                'correct_option': 'b',
                'pair_type': 'credit_debit',
                'explanation': 'Bank Loan is a liability (credit).',
              },
              {
                'question': 'ui_q2',
                'prompt': 'Equipment',
                'points': 10,
                'options': [
                  {'option': 'a', 'text': 'Debit'},
                  {'option': 'b', 'text': 'Credit'},
                ],
                'correct_option': 'a',
                'pair_type': 'credit_debit',
                'explanation': 'Equipment is an asset (debit).',
              },
            ],
          }),
          201,
        );
      }
      if (request.url.path == '/api/v1/quiz/sort-it-out/complete') {
        return http.Response(
          jsonEncode({
            'session': 'ui_sess_1',
            'pair_type': 'credit_debit',
            'total_questions': 2,
            'correct_count': 2,
            'timeout_count': 0,
            'best_streak': 2,
            'accuracy_percentage': 100.0,
            'final_score': 30,
            'coins_awarded': 15,
            'xp_awarded': 45,
            'gems_awarded': 2,
            'score_breakdown': {
              'base_points': 20,
              'speed_bonus': 10,
              'combo_bonus': 0,
              'final_score': 30,
            },
            'cards_review': [
              {
                'question': 'ui_q1',
                'prompt': 'Bank Loan',
                'selected_option': 'b',
                'correct_option': 'b',
                'is_correct': true,
                'is_timeout': false,
                'time_taken_ms': 1200,
                'base_points': 10,
                'speed_bonus': 5,
                'combo_bonus': 0,
                'points_earned': 15,
                'explanation': 'Bank Loan is a liability (credit).',
              },
              {
                'question': 'ui_q2',
                'prompt': 'Equipment',
                'selected_option': 'a',
                'correct_option': 'a',
                'is_correct': true,
                'is_timeout': false,
                'time_taken_ms': 1400,
                'base_points': 10,
                'speed_bonus': 5,
                'combo_bonus': 0,
                'points_earned': 15,
                'explanation': 'Equipment is an asset (debit).',
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

    testWidgets('renders dynamic labels, card stack, buttons, and completes batch', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SortItOutScreen(topicId: 'accounting'),
          ),
        ),
      );

      // Wait for session create
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify header & dynamic labels
      expect(find.text('Sort It Out'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Bank Loan'), findsOneWidget);
      expect(find.text('Debit'), findsWidgets);
      expect(find.text('Credit'), findsWidgets);
      expect(find.byKey(const Key('sort-active-card')), findsOneWidget);

      // Button B (Credit) tap for card 1 (Bank Loan)
      final creditBtn = find.byKey(const ValueKey('sort-bucket-credit'));
      await tester.tap(creditBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 650));

      // Card 2 is now active: Equipment
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);

      // Swipe Left for card 2 (Equipment -> Debit)
      await tester.drag(find.byKey(const Key('sort-active-card')), const Offset(-160, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // End of deck triggers completion -> Result screen appears!
      expect(find.text('Sort It Out — Results'), findsOneWidget);
      expect(find.text('Official Score'), findsOneWidget);
      expect(find.text('30'), findsAtLeast(1));
      expect(find.text('+45 XP'), findsOneWidget);
      expect(find.text('+15 Coins'), findsOneWidget);
      expect(find.text('Score Breakdown'), findsOneWidget);
      expect(find.text('Base Points'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Speed Bonus'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('Answer review'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
