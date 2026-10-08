// ignore_for_file: avoid_print, unused_local_variable
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/remote/auth_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';

void main() {
  test('Live Railway Sudden Death WebSocket Test', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    final config = ApiConfig.defaultConfig(); // Uses Railway production url
    print('Using BASE_URL: ${config.baseUrl}');
    print('Using WS_URL: ${config.gameWsUrl}');
    final apiClient = ApiClient(config: config, storage: storage);
    final authRemote = AuthRemoteDatasource(apiClient: apiClient, storage: storage);
    final suddenRemote = SuddenDeathRemoteDatasource(
      apiClient: apiClient,
      storage: storage,
      apiConfig: config,
    );

    // 1. Login
    final user = await authRemote.login(
      email: 'player@example.com',
      password: 'secretpassword123',
    );
    print('Logged in client: ${user.id} (${user.email})');

    // 2. Create session
    final sessionId = await suddenRemote.createSession(
      topicId: 'accounting',
      questionCount: 10,
    );
    print('Session created on Railway: $sessionId');

    final completerQ1 = Completer<WsQuestionEvent>();
    final completerAnswer = Completer<WsAnswerResultEvent>();
    final completerGameOver = Completer<WsGameOverEvent>();
    final completerError = Completer<WsErrorEvent>();

    suddenRemote.events.listen((event) {
      print('WS EVENT RECEIVED: ${event.runtimeType}');
      if (event is WsQuestionEvent) {
        print('-> Question: ${event.payload.question}, prompt: "${event.payload.prompt}", options: ${event.payload.options.map((o) => "${o.option}:${o.text}").toList()}, timeLimit: ${event.payload.timeLimitMs}, remaining: ${event.payload.remainingTimeMs}');
        if (!completerQ1.isCompleted) completerQ1.complete(event);
      } else if (event is WsAnswerResultEvent) {
        print('-> AnswerResult: isCorrect=${event.payload.isCorrect}, yourScore=${event.payload.yourScore}, isTimeout=${event.payload.isTimeout}');
        if (!completerAnswer.isCompleted) completerAnswer.complete(event);
      } else if (event is WsGameOverEvent) {
        print('-> GameOver: finalScore=${event.payload.finalScore}, endReason=${event.payload.endReason}');
        if (!completerGameOver.isCompleted) completerGameOver.complete(event);
      } else if (event is WsErrorEvent) {
        print('-> Error: code=${event.payload.code}, msg=${event.payload.message}');
        if (!completerError.isCompleted) completerError.complete(event);
      } else if (event is WsUnknownEvent) {
        print('-> UnknownEvent: type=${event.type}, data=${event.rawData}');
      }
    });

    // 3. Connect WebSocket
    print('Connecting to WebSocket...');
    await suddenRemote.connect(sessionId: sessionId);
    print('Connected! isConnected=${suddenRemote.isConnected}');

    // 4. Wait for Q1
    final q1 = await completerQ1.future.timeout(const Duration(seconds: 10));
    print('Q1 received successfully: ${q1.payload.question}');

    // 5. Submit answer
    final selectedOption = q1.payload.options.first.option;
    print('Submitting answer: option=$selectedOption for question=${q1.payload.question}');
    suddenRemote.submitAnswer(
      question: q1.payload.question,
      option: selectedOption,
      timeTakenMs: 1500,
    );

    // 6. Wait for answer result or error
    try {
      final res = await completerAnswer.future.timeout(const Duration(seconds: 10));
      print('Answer result received successfully!');
    } catch (e) {
      print('Answer result timed out or failed: $e');
    }

    await Future.delayed(const Duration(seconds: 2));
    await suddenRemote.disconnect();
    apiClient.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
