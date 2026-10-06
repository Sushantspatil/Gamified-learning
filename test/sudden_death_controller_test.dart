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
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_socket_client.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sudden_death_providers.dart';

class _FakeLocalStorage implements LocalStorageService {
  final Map<String, String> _values = {};
  @override
  String? getString(String key) => _values[key];
  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
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
  Future<bool> remove(String key) async => _values.remove(key) != null;
}

WsQuestionPayload _question(
  int number, {
  bool addTimeUsed = false,
  bool skipUsed = false,
}) => WsQuestionPayload(
  question: 'q-$number',
  prompt: 'Question $number',
  points: 10,
  options: const [
    WsOptionPayload(option: 'a', text: 'A'),
    WsOptionPayload(option: 'b', text: 'B'),
    WsOptionPayload(option: 'c', text: 'C'),
    WsOptionPayload(option: 'd', text: 'D'),
  ],
  timeLimitMs: 15000,
  remainingTimeMs: addTimeUsed ? 19800 : 15000,
  addTimeUsed: addTimeUsed,
  skipUsed: skipUsed,
  questionNumber: number,
  totalQuestions: 10,
);

WsAnswerResultPayload _answerResult(
  int number, {
  bool isCorrect = true,
  bool isSkipped = false,
  bool isTimeout = false,
}) => WsAnswerResultPayload(
  question: 'q-$number',
  option: isSkipped ? 'skip' : 'a',
  correctOption: 'a',
  isCorrect: isCorrect,
  isSkipped: isSkipped,
  pointsEarned: isCorrect ? 10 : 0,
  coinsEarned: 0,
  yourScore: isCorrect ? number * 10 : (number - 1) * 10,
  isTimeout: isTimeout,
);

class _FakeSuddenDeathSocketClient implements SuddenDeathSocketClient {
  final StreamController<WsServerEvent> _events =
      StreamController<WsServerEvent>.broadcast();
  bool _connected = false;
  WsQuestionPayload questionOnConnect = _question(1);
  final List<WsInboundMessage> sentMessages = [];

  @override
  Stream<WsServerEvent> get events => _events.stream;
  @override
  bool get isConnected => _connected;
  @override
  Future<void> connect(Uri uri) async {
    _connected = true;
    scheduleMicrotask(() => _events.add(WsQuestionEvent(questionOnConnect)));
  }

  @override
  void send(WsInboundMessage message) => sentMessages.add(message);
  @override
  Future<void> close([int? code, String? reason]) async {
    _connected = false;
  }

  void emit(WsServerEvent event) => _events.add(event);
  Future<void> dispose() => _events.close();
}

void main() {
  group('SuddenDeathController server-authoritative flow', () {
    late _FakeLocalStorage storage;
    late _FakeSuddenDeathSocketClient socket;
    late ProviderContainer container;
    const request = QuizSessionRequest(
      topicId: 'accounting',
      subjectId: 'commerce',
      chapterId: 'chapter-1',
      quizType: QuestionType.suddenDeath,
    );

    setUp(() async {
      storage = _FakeLocalStorage();
      await storage.setString(StorageKeys.authToken, 'token');
      socket = _FakeSuddenDeathSocketClient();
      const config = ApiConfig(baseUrl: 'http://localhost:8080/api/v1');
      final httpClient = MockClient((request) async {
        if (request.url.path.contains('/quiz/sessions/create')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Session created',
              'data': {
                'session': 'session-1',
                'topic': 'accounting',
                'total_questions': 10,
                'questions': <Object>[],
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
        httpClient: httpClient,
      );
      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socket,
      );
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          apiConfigProvider.overrideWithValue(config),
          apiClientProvider.overrideWithValue(apiClient),
          suddenDeathSocketClientProvider.overrideWithValue(socket),
          suddenDeathDatasourceProvider.overrideWithValue(datasource),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await socket.dispose();
    });

    Future<ProviderSubscription<AsyncValue<SuddenDeathViewState>>>
    start() async {
      final subscription = container.listen(
        suddenDeathControllerProvider(request),
        (_, _) {},
      );
      await container.read(suddenDeathControllerProvider(request).future);
      return subscription;
    }

    SuddenDeathViewState current() =>
        container.read(suddenDeathControllerProvider(request)).requireValue;
    Future<void> emit(WsServerEvent event) async {
      socket.emit(event);
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'renders the first backend question instead of REST question data',
      () async {
        final subscription = await start();
        expect(current().status, SuddenDeathStatus.questionActive);
        expect(current().currentQuestion?.id, 'q-1');
        expect(current().currentIndex, 0);
        expect(current().questions.map((q) => q.id), ['q-1']);
        subscription.close();
      },
    );

    test('answer waits for answer_result and next question frame', () async {
      final subscription = await start();
      final controller = container.read(
        suddenDeathControllerProvider(request).notifier,
      );
      controller.submitAnswer('a');
      expect(current().isSubmitting, isTrue);
      expect(current().status, SuddenDeathStatus.questionActive);
      expect(current().currentIndex, 0);
      expect(socket.sentMessages.single.type, 'submit_answer');
      expect(socket.sentMessages.single.data['question'], 'q-1');

      await emit(WsAnswerResultEvent(_answerResult(1)));
      expect(current().status, SuddenDeathStatus.showingResult);
      expect(current().currentQuestion?.id, 'q-1');
      expect(current().currentIndex, 0);

      await emit(WsQuestionEvent(_question(2)));
      expect(current().status, SuddenDeathStatus.questionActive);
      expect(current().currentQuestion?.id, 'q-2');
      expect(current().currentIndex, 1);
      expect(current().selectedOptionId, isNull);
      subscription.close();
    });

    test(
      'stale result and stale question cannot change active question',
      () async {
        final subscription = await start();
        await emit(WsAnswerResultEvent(_answerResult(2)));
        await emit(WsQuestionEvent(_question(0)));
        expect(current().status, SuddenDeathStatus.questionActive);
        expect(current().currentQuestion?.id, 'q-1');
        expect(current().currentIndex, 0);
        subscription.close();
      },
    );

    test('add time waits for authoritative remaining_time_ms', () async {
      final subscription = await start();
      final controller = container.read(
        suddenDeathControllerProvider(request).notifier,
      );
      await controller.addFiveSeconds();
      await controller.addFiveSeconds();
      expect(current().isAddTimePending, isTrue);
      expect(current().addTimeUsed, isFalse);
      expect(current().remainingTimeMs, 15000);
      expect(socket.sentMessages, hasLength(1));
      expect(socket.sentMessages.single.data['power_up'], 'add_time');
      expect(socket.sentMessages.single.data['question'], 'q-1');

      await emit(
        const WsPowerUpResultEvent(
          WsPowerUpResultPayload(
            question: 'q-1',
            powerUp: 'add_time',
            addedTimeMs: 5000,
            remainingTimeMs: 9600,
          ),
        ),
      );
      expect(current().isAddTimePending, isFalse);
      expect(current().addTimeUsed, isTrue);
      expect(current().remainingTimeMs, 9600);
      subscription.close();
    });

    test('failed or stale add time never changes displayed time', () async {
      final subscription = await start();
      final controller = container.read(
        suddenDeathControllerProvider(request).notifier,
      );
      await controller.addFiveSeconds();
      await emit(
        const WsPowerUpResultEvent(
          WsPowerUpResultPayload(
            question: 'q-2',
            powerUp: 'add_time',
            addedTimeMs: 5000,
            remainingTimeMs: 20000,
          ),
        ),
      );
      expect(current().remainingTimeMs, 15000);
      await emit(
        const WsErrorEvent(
          WsErrorPayload(code: 'stale_question', message: 'stale question'),
        ),
      );
      expect(current().remainingTimeMs, 15000);
      expect(current().addTimeUsed, isFalse);
      expect(current().isAddTimePending, isFalse);
      subscription.close();
    });

    test('skip waits for backend result and next question', () async {
      final subscription = await start();
      final controller = container.read(
        suddenDeathControllerProvider(request).notifier,
      );
      controller.skipQuestion();
      expect(current().currentIndex, 0);
      expect(current().skipUsed, isFalse);
      expect(current().isSubmitting, isTrue);
      expect(socket.sentMessages.single.data['power_up'], 'skip');
      expect(socket.sentMessages.single.data['question'], 'q-1');

      await emit(
        WsAnswerResultEvent(
          _answerResult(1, isCorrect: false, isSkipped: true),
        ),
      );
      expect(current().status, SuddenDeathStatus.showingResult);
      expect(current().currentIndex, 0);
      expect(current().skipUsed, isTrue);

      await emit(WsQuestionEvent(_question(2, skipUsed: true)));
      expect(current().currentQuestion?.id, 'q-2');
      expect(current().currentIndex, 1);
      expect(current().skipUsed, isTrue);
      subscription.close();
    });

    test(
      'timeout and game over are accepted only from backend frames',
      () async {
        final subscription = await start();
        await emit(
          WsAnswerResultEvent(
            _answerResult(1, isCorrect: false, isTimeout: true),
          ),
        );
        expect(current().status, SuddenDeathStatus.showingResult);
        expect(current().lastAnswerResult?.isTimeout, isTrue);
        await emit(
          const WsGameOverEvent(
            WsGameOverPayload(
              finalScore: 0,
              totalQuestions: 10,
              correctCount: 0,
              coinsEarned: 0,
              xpEarned: 0,
              gemsEarned: 0,
              newLevel: 1,
              didLevelUp: false,
              gameMode: 'sudden_death',
              endReason: 'eliminated',
              endedEarly: true,
            ),
          ),
        );
        expect(current().status, SuddenDeathStatus.gameOver);
        expect(current().result?.endedEarly, isTrue);
        subscription.close();
      },
    );

    test('Q1 through Q10 always match the latest backend question', () async {
      final subscription = await start();
      for (var number = 1; number <= 10; number++) {
        expect(current().currentQuestion?.id, 'q-$number');
        expect(current().currentIndex, number - 1);
        await emit(WsAnswerResultEvent(_answerResult(number)));
        expect(current().currentQuestion?.id, 'q-$number');
        expect(current().currentIndex, number - 1);
        if (number < 10) await emit(WsQuestionEvent(_question(number + 1)));
      }
      await emit(
        const WsGameOverEvent(
          WsGameOverPayload(
            finalScore: 100,
            totalQuestions: 10,
            correctCount: 10,
            coinsEarned: 0,
            xpEarned: 0,
            gemsEarned: 0,
            newLevel: 1,
            didLevelUp: false,
            gameMode: 'sudden_death',
            endReason: 'cleared',
            endedEarly: false,
          ),
        ),
      );
      expect(current().status, SuddenDeathStatus.gameOver);
      expect(current().result?.endedEarly, isFalse);
      subscription.close();
    });

    test('reconnect resync preserves backend extended deadline', () async {
      final subscription = await start();
      await socket.close();
      socket.questionOnConnect = _question(1, addTimeUsed: true);
      final controller = container.read(
        suddenDeathControllerProvider(request).notifier,
      );
      await controller.addFiveSeconds();
      await Future<void>.delayed(Duration.zero);
      expect(current().currentQuestion?.id, 'q-1');
      expect(current().remainingTimeMs, 19800);
      expect(current().addTimeUsed, isTrue);
      expect(
        socket.sentMessages.where((message) => message.type == 'use_power_up'),
        isEmpty,
      );
      subscription.close();
    });
  });
}
