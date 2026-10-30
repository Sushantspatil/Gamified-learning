import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_rest_client.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';

class _Storage implements LocalStorageService {
  @override
  String? getString(String key) => 'token';
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  int? getInt(String key) => null;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> remove(String key) async => true;
}

Map<String, dynamic> _question(String code, int remainingMs) => {
  'type': 'question',
  'data': {
    'question': code,
    'prompt': 'Prompt $code',
    'points': 10,
    'options': [
      {'option': 'a', 'text': 'A'},
      {'option': 'b', 'text': 'B'},
    ],
    'time_limit_ms': 15000,
    'remaining_time_ms': remainingMs,
    'question_number': 1,
    'total_questions': 2,
  },
};

Map<String, dynamic> _result(String code, {bool timeout = false}) => {
  'type': 'answer_result',
  'data': {
    'question': code,
    'option': timeout ? 'timeout' : 'a',
    'correct_option': 'a',
    'is_correct': !timeout,
    'is_skipped': false,
    'points_earned': timeout ? 0 : 10,
    'coins_earned': 0,
    'your_score': 10,
    'is_timeout': timeout,
  },
};

const _gameOver = {
  'type': 'game_over',
  'data': {
    'final_score': 10,
    'total_questions': 2,
    'correct_count': 1,
    'skipped_count': 0,
    'best_streak': 1,
    'coins_earned': 1,
    'xp_earned': 1,
    'gems_earned': 0,
    'new_level': 1,
    'did_level_up': false,
    'game_mode': 'sudden_death',
    'end_reason': 'timeout',
    'ended_early': true,
    'completed_successfully': false,
  },
};

void main() {
  late List<http.Request> requests;
  late List<List<Map<String, dynamic>>> replies;
  late RestSuddenDeathClient client;

  setUp(() {
    requests = [];
    replies = [];
    final api = ApiClient(
      config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
      storage: _Storage(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (replies.isEmpty) return http.Response('{"message":"boom"}', 500);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'events': replies.removeAt(0)},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    client = RestSuddenDeathClient(api);
  });

  tearDown(() => client.dispose());

  Future<void> connect() =>
      client.connect(Uri(queryParameters: {'session_id': 'sess-1'}));

  test('join, answer, auto-timeout and game over flow', () async {
    final events = <WsServerEvent>[];
    final sub = client.events.listen(events.add);
    replies.add([_question('q1', 15000)]);
    await connect();
    expect(client.isConnected, isTrue);
    await pumpEventQueue();
    expect(requests.single.url.path, '/api/v1/quiz/sudden-death/question');
    expect(jsonDecode(requests.single.body), {'session': 'sess-1'});
    expect(events.single, isA<WsQuestionEvent>());

    replies.add([_result('q1'), _question('q2', 50)]);
    client.send(WsInboundMessage.submitAnswer(question: 'q1', option: 'a'));
    await pumpEventQueue();
    expect(
      events.last,
      isA<WsAnswerResultEvent>(),
      reason: 'next question waits for the transition',
    );
    await Future<void>.delayed(RestSuddenDeathClient.transitionDelay);
    await pumpEventQueue();
    expect(events.last, isA<WsQuestionEvent>());

    replies.add([_result('q2', timeout: true), _gameOver]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await pumpEventQueue();
    final timeoutBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(requests.last.url.path, '/api/v1/quiz/sudden-death/answer');
    expect(timeoutBody['option'], 'timeout');
    expect(timeoutBody['question'], 'q2');
    expect(events.whereType<WsGameOverEvent>(), hasLength(1));
    expect((events.last as WsErrorEvent).payload.code, 'socket_closed_normal');
    expect(client.isConnected, isFalse);
    await sub.cancel();
  });

  test('server failure surfaces as reconnectable socket_error', () async {
    final events = <WsServerEvent>[];
    final sub = client.events.listen(events.add);
    await connect();
    await pumpEventQueue();
    expect((events.single as WsErrorEvent).payload.code, 'socket_error');
    await sub.cancel();
  });

  test('send before connect reports socket_closed', () async {
    final events = <WsServerEvent>[];
    final sub = client.events.listen(events.add);
    client.send(WsInboundMessage.joinGame());
    await pumpEventQueue();
    expect((events.single as WsErrorEvent).payload.code, 'socket_closed');
    expect(requests, isEmpty);
    await sub.cancel();
  });
}
