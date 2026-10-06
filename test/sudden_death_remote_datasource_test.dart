import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_socket_client.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';

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
  int? closedCode;
  String? closedReason;

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
    closedCode = code;
    closedReason = reason;
  }

  void emitEvent(WsServerEvent event) {
    _eventsController.add(event);
  }

  void dispose() {
    _eventsController.close();
  }
}

void main() {
  group('SuddenDeathRemoteDatasource', () {
    late _FakeLocalStorage storage;
    late _FakeSuddenDeathSocketClient socketClient;
    late ApiConfig config;

    setUp(() {
      storage = _FakeLocalStorage();
      socketClient = _FakeSuddenDeathSocketClient();
      config = const ApiConfig(baseUrl: 'http://localhost:8080/api/v1');
    });

    tearDown(() {
      socketClient.dispose();
    });

    test('createSession sends POST request and extracts session ID', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/quiz/sessions/create');
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decoded['topic'], 'accounting');
        expect(decoded['question_count'], 10);
        expect(decoded['abandon_stale'], true);

        return http.Response(
          jsonEncode({
            'code': 200,
            'message': 'Session created successfully',
            'data': {
              'session': 'sess-uuid-456',
              'topic': 'accounting',
              'total_questions': 10,
              'questions': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: mockHttpClient,
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      final sessionId = await datasource.createSession(topicId: 'accounting');
      expect(sessionId, 'sess-uuid-456');
      expect(datasource.activeSessionId, 'sess-uuid-456');
    });

    test('connect throws AuthException when token is absent', () async {
      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      expect(
        () => datasource.connect(sessionId: 'sess-123'),
        throwsA(isA<AuthException>()),
      );
    });

    test(
      'connect uses token from storage and constructs valid ws URI',
      () async {
        await storage.setString(StorageKeys.authToken, 'jwt-token-xyz');

        final apiClient = ApiClient(
          config: config,
          storage: storage,
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        );

        final datasource = SuddenDeathRemoteDatasource(
          apiClient: apiClient,
          storage: storage,
          apiConfig: config,
          socketClient: socketClient,
        );

        await datasource.connect(sessionId: 'sess-test-888');

        expect(socketClient.isConnected, isTrue);
        expect(socketClient.connectedUri, isNotNull);
        expect(socketClient.connectedUri!.scheme, 'ws');
        expect(socketClient.connectedUri!.path, '/ws/game');
        expect(
          socketClient.connectedUri!.queryParameters['session_id'],
          'sess-test-888',
        );
        expect(
          socketClient.connectedUri!.queryParameters['token'],
          'jwt-token-xyz',
        );
      },
    );

    test('submitAnswer sends proper inbound message frame', () async {
      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      await storage.setString(StorageKeys.authToken, 'token-123');
      await datasource.connect(sessionId: 'active-sess');

      datasource.submitAnswer(
        question: 'q-code-1',
        option: 'b',
        selectedText: 'Income Statement',
        timeTakenMs: 2350,
      );

      expect(socketClient.sentMessages.length, 1);
      final msg = socketClient.sentMessages.first;
      expect(msg.type, 'submit_answer');
      expect(msg.data['question'], 'q-code-1');
      expect(msg.data['option'], 'b');
      expect(msg.data['selected_text'], 'Income Statement');
      expect(msg.data['time_taken_ms'], 2350);
      expect(msg.data['session'], 'active-sess');
    });

    test('useFiftyFifty sends power-up inbound message frame', () async {
      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      await storage.setString(StorageKeys.authToken, 'token-123');
      await datasource.connect(sessionId: 'sess-5050');

      datasource.useFiftyFifty(question: 'q-code-2');

      expect(socketClient.sentMessages.length, 1);
      final msg = socketClient.sentMessages.first;
      expect(msg.type, 'use_power_up');
      expect(msg.data['power_up'], 'fifty_fifty');
      expect(msg.data['question'], 'q-code-2');
      expect(msg.data['session'], 'sess-5050');
    });

    test(
      'addTime sends authoritative power-up inbound message frame',
      () async {
        final apiClient = ApiClient(
          config: config,
          storage: storage,
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        );

        final datasource = SuddenDeathRemoteDatasource(
          apiClient: apiClient,
          storage: storage,
          apiConfig: config,
          socketClient: socketClient,
        );

        await storage.setString(StorageKeys.authToken, 'token-123');
        await datasource.connect(sessionId: 'sess-add-time');

        datasource.addTime(question: 'q-code-2');

        expect(socketClient.sentMessages.length, 1);
        final msg = socketClient.sentMessages.first;
        expect(msg.type, 'use_power_up');
        expect(msg.data['power_up'], 'add_time');
        expect(msg.data['question'], 'q-code-2');
        expect(msg.data['session'], 'sess-add-time');
      },
    );

    test('joinGame sends join_game message frame with session', () async {
      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      await storage.setString(StorageKeys.authToken, 'token-123');
      await datasource.connect(sessionId: 'sess-join');

      datasource.joinGame();

      expect(socketClient.sentMessages.length, 1);
      final msg = socketClient.sentMessages.first;
      expect(msg.type, 'join_game');
      expect(msg.data['session'], 'sess-join');
    });

    test('events stream forwards events from socket client', () async {
      final apiClient = ApiClient(
        config: config,
        storage: storage,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final datasource = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: config,
        socketClient: socketClient,
      );

      final eventsList = <WsServerEvent>[];
      final sub = datasource.events.listen(eventsList.add);

      const testPayload = WsPowerUpResultPayload(
        question: 'q-code-test',
        hiddenOptions: ['a', 'c'],
      );
      socketClient.emitEvent(const WsPowerUpResultEvent(testPayload));

      await Future<void>.delayed(Duration.zero);
      expect(eventsList.length, 1);
      expect(eventsList.first, isA<WsPowerUpResultEvent>());
      final received = eventsList.first as WsPowerUpResultEvent;
      expect(received.payload.question, 'q-code-test');
      expect(received.payload.hiddenOptions, ['a', 'c']);

      await sub.cancel();
    });

    test(
      'disconnect closes socket client and clears activeSessionId',
      () async {
        final apiClient = ApiClient(
          config: config,
          storage: storage,
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        );

        final datasource = SuddenDeathRemoteDatasource(
          apiClient: apiClient,
          storage: storage,
          apiConfig: config,
          socketClient: socketClient,
        );

        await storage.setString(StorageKeys.authToken, 'token-123');
        await datasource.connect(sessionId: 'sess-dc');
        expect(datasource.activeSessionId, 'sess-dc');

        await datasource.disconnect(1000, 'Game over');

        expect(socketClient.isConnected, isFalse);
        expect(socketClient.closedCode, 1000);
        expect(socketClient.closedReason, 'Game over');
        expect(datasource.activeSessionId, isNull);
      },
    );
  });
}
