import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/network_providers.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_socket_client.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sudden_death_providers.dart';

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

class _FakeSuddenDeathSocketClient implements SuddenDeathSocketClient {
  final StreamController<WsServerEvent> _eventsController =
      StreamController<WsServerEvent>.broadcast();
  bool _connected = false;
  Uri? connectedUri;
  final List<WsInboundMessage> sentMessages = [];

  @override
  Stream<WsServerEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(Uri uri) async {
    connectedUri = uri;
    _connected = true;
  }

  @override
  void send(WsInboundMessage message) {
    sentMessages.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _connected = false;
  }

  void emitEvent(WsServerEvent event) {
    _eventsController.add(event);
  }

  void dispose() {
    _eventsController.close();
  }
}

void main() {
  group('SuddenDeathController Riverpod State Machine', () {
    late _FakeLocalStorage storage;
    late _FakeSuddenDeathSocketClient socketClient;
    late ProviderContainer container;

    const testRequest = QuizSessionRequest(
      topicId: 'accounting',
      subjectId: 'commerce',
      chapterId: 'chap-1',
      quizType: QuestionType.suddenDeath,
    );

    setUp(() async {
      storage = _FakeLocalStorage();
      await storage.setString(StorageKeys.authToken, 'mock-jwt-token');

      socketClient = _FakeSuddenDeathSocketClient();

      final config = const ApiConfig(baseUrl: 'http://localhost:8080/api/v1');

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/quiz/sessions/create')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Session created',
              'data': {
                'session': 'sess-riverpod-999',
                'topic': 'accounting',
                'total_questions': 2,
                'questions': [
                  {
                    'question': 'q-acc-01',
                    'prompt': 'What is Double Entry Bookkeeping?',
                    'points': 10,
                    'options': [
                      {'option': 'a', 'text': 'Single ledger'},
                      {'option': 'b', 'text': 'Debit and credit'},
                      {'option': 'c', 'text': 'Tax report'},
                      {'option': 'd', 'text': 'Audit'},
                    ],
                    'correct_option': 'b',
                  },
                  {
                    'question': 'q-acc-02',
                    'prompt': 'Which account has a credit balance?',
                    'points': 10,
                    'options': [
                      {'option': 'a', 'text': 'Liabilities'},
                      {'option': 'b', 'text': 'Assets'},
                      {'option': 'c', 'text': 'Expenses'},
                      {'option': 'd', 'text': 'Drawings'},
                    ],
                    'correct_option': 'a',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/quiz/answers/evaluate')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Answer evaluated',
              'data': {
                'question': 'q-acc-01',
                'option': 'b',
                'correct_option': 'b',
                'is_correct': true,
                'points_earned': 10,
                'coins_earned': 0,
                'combo_streak': 1,
                'total_score': 10,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/quiz/sessions/complete')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Session completed',
              'data': {
                'session': 'sess-riverpod-999',
                'final_score': 10,
                'total_questions': 2,
                'correct_count': 1,
                'coins_awarded': 7,
                'xp_awarded': 15,
                'gems_awarded': 1,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: mockHttp,
      );

      final suddenRemoteDs = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      final quizRemoteDs = QuizRemoteDatasource(apiClient: apiClient);

      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          apiConfigProvider.overrideWithValue(config),
          apiClientProvider.overrideWithValue(apiClient),
          suddenDeathSocketClientProvider.overrideWithValue(socketClient),
          suddenDeathDatasourceProvider.overrideWithValue(suddenRemoteDs),
          quizDatasourceProvider.overrideWithValue(quizRemoteDs),
        ],
      );
    });

    tearDown(() {
      socketClient.dispose();
      container.dispose();
    });

    test(
      'build preloads all questions and starts with questionActive',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );

        final initialVal = await container.read(
          suddenDeathControllerProvider(testRequest).future,
        );

        expect(initialVal.status, SuddenDeathStatus.questionActive);
        expect(initialVal.sessionId, 'sess-riverpod-999');
        expect(initialVal.questions.length, 2);
        expect(initialVal.currentQuestion?.id, 'q-acc-01');
        expect(initialVal.currentIndex, 0);
        expect(initialVal.remainingTimeMs, 15000);

        sub.close();
      },
    );

    test(
      'addFiveSeconds waits for authoritative remaining time and sends once',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );
        await container.read(suddenDeathControllerProvider(testRequest).future);

        final controller = container.read(
          suddenDeathControllerProvider(testRequest).notifier,
        );
        await controller.addFiveSeconds();
        await controller.addFiveSeconds();

        var current = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(current.isAddTimePending, isTrue);
        expect(current.addTimeUsed, isFalse);
        expect(current.remainingTimeMs, 15000);

        final addTimeMessages = socketClient.sentMessages
            .where((message) => message.type == 'use_power_up')
            .toList();
        expect(addTimeMessages, hasLength(1));
        expect(addTimeMessages.single.data['power_up'], 'add_time');
        expect(addTimeMessages.single.data['question'], 'q-acc-01');

        socketClient.emitEvent(
          const WsPowerUpResultEvent(
            WsPowerUpResultPayload(
              question: 'q-acc-01',
              powerUp: 'add_time',
              addedTimeMs: 5000,
              remainingTimeMs: 9600,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        current = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(current.isAddTimePending, isFalse);
        expect(current.addTimeUsed, isTrue);
        expect(current.remainingTimeMs, 9600);

        sub.close();
      },
    );

    test(
      'failed add_time does not change the displayed remaining time',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );
        await container.read(suddenDeathControllerProvider(testRequest).future);

        final controller = container.read(
          suddenDeathControllerProvider(testRequest).notifier,
        );
        await controller.addFiveSeconds();
        socketClient.emitEvent(
          const WsErrorEvent(
            WsErrorPayload(
              code: 'stale_question',
              message: 'power-up question does not match the active question',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final current = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(current.isAddTimePending, isFalse);
        expect(current.addTimeUsed, isFalse);
        expect(current.remainingTimeMs, 15000);

        sub.close();
      },
    );

    test('question resync restores extended time and usage state', () async {
      final sub = container.listen(
        suddenDeathControllerProvider(testRequest),
        (_, _) {},
      );
      await container.read(suddenDeathControllerProvider(testRequest).future);

      socketClient.emitEvent(
        const WsQuestionEvent(
          WsQuestionPayload(
            question: 'q-acc-01',
            prompt: 'What is Double Entry Bookkeeping?',
            points: 10,
            options: [],
            timeLimitMs: 15000,
            remainingTimeMs: 8700,
            addTimeUsed: true,
            questionNumber: 1,
            totalQuestions: 2,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final current = container
          .read(suddenDeathControllerProvider(testRequest))
          .value!;
      expect(current.remainingTimeMs, 8700);
      expect(current.addTimeUsed, isTrue);
      expect(current.isAddTimePending, isFalse);

      sub.close();
    });

    test(
      'submitAnswer evaluates correct answer instantly without network wait',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );
        await container.read(suddenDeathControllerProvider(testRequest).future);

        final controller = container.read(
          suddenDeathControllerProvider(testRequest).notifier,
        );

        // Submit correct answer 'b'
        controller.submitAnswer('b');

        final evaluatedState = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(evaluatedState.status, SuddenDeathStatus.showingResult);
        expect(evaluatedState.currentStreak, 1);
        expect(evaluatedState.bestStreak, 1);
        expect(evaluatedState.currentScore, 10);
        expect(evaluatedState.lastAnswerResult?.isCorrect, isTrue);

        sub.close();
      },
    );

    test(
      'useFiftyFifty hides 2 incorrect choices client-side instantly',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );
        await container.read(suddenDeathControllerProvider(testRequest).future);

        final controller = container.read(
          suddenDeathControllerProvider(testRequest).notifier,
        );
        controller.useFiftyFifty();

        final powerUpState = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(powerUpState.fiftyFiftyUsed, isTrue);
        expect(powerUpState.hiddenOptionIds.length, 2);
        // Correct option 'b' must not be hidden
        expect(powerUpState.hiddenOptionIds.contains('b'), isFalse);

        sub.close();
      },
    );

    test(
      'skipQuestion marks skipUsed and advances without eliminating',
      () async {
        final sub = container.listen(
          suddenDeathControllerProvider(testRequest),
          (_, _) {},
        );
        await container.read(suddenDeathControllerProvider(testRequest).future);

        final controller = container.read(
          suddenDeathControllerProvider(testRequest).notifier,
        );
        controller.skipQuestion();

        final state = container
            .read(suddenDeathControllerProvider(testRequest))
            .value!;
        expect(state.skipUsed, isTrue);
        expect(state.currentStreak, 0);
        expect(state.currentIndex, 1);
        expect(state.currentQuestion?.id, 'q-acc-02');

        sub.close();
      },
    );

    test('handleTimeout triggers elimination on countdown expiry', () async {
      final sub = container.listen(
        suddenDeathControllerProvider(testRequest),
        (_, _) {},
      );
      await container.read(suddenDeathControllerProvider(testRequest).future);

      final controller = container.read(
        suddenDeathControllerProvider(testRequest).notifier,
      );
      controller.handleTimeout();

      final timeoutState = container
          .read(suddenDeathControllerProvider(testRequest))
          .value!;
      expect(timeoutState.status, SuddenDeathStatus.showingResult);
      expect(timeoutState.lastAnswerResult?.isTimeout, isTrue);
      expect(timeoutState.currentStreak, 0);

      sub.close();
    });
  });
}
