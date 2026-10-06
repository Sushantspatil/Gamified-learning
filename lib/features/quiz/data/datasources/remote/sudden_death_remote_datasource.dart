import 'dart:async';

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/api_endpoints.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import '../../models/sudden_death_ws_dto.dart';
import 'sudden_death_socket_client.dart';

class SuddenDeathRemoteDatasource {
  final ApiClient _apiClient;
  final LocalStorageService _storage;
  final ApiConfig _apiConfig;
  final SuddenDeathSocketClient _socketClient;

  String? _activeSessionId;
  List<SuddenDeathQuestion>? _activeSessionQuestions;

  SuddenDeathRemoteDatasource({
    required ApiClient apiClient,
    required LocalStorageService storage,
    required ApiConfig apiConfig,
    SuddenDeathSocketClient? socketClient,
  }) : _apiClient = apiClient,
       _storage = storage,
       _apiConfig = apiConfig,
       _socketClient = socketClient ?? IoSuddenDeathSocketClient();

  String? get activeSessionId => _activeSessionId;
  List<SuddenDeathQuestion>? get activeSessionQuestions =>
      _activeSessionQuestions;
  Stream<WsServerEvent> get events => _socketClient.events;
  bool get isConnected => _socketClient.isConnected;

  /// Creates a live quiz session on the Go backend in PostgreSQL and preloads
  /// all questions, options, and correct answers from the database.
  Future<String> createSession({
    required String topicId,
    int questionCount = 10,
    List<String>? questionCodes,
    String gameMode = 'sudden_death',
  }) async {
    _activeSessionId = null;
    _activeSessionQuestions = null;
    final backendTopic = topicId.contains('accounting')
        ? 'accounting'
        : topicId;
    final requestDto = CreateSessionRequestDto(
      topic: backendTopic,
      questionCount: questionCount,
      abandonStale: true,
      questionCodes: questionCodes,
      gameMode: gameMode,
    );

    final response = await _apiClient.post(
      ApiEndpoints.quizCreateSession,
      body: requestDto.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final sessionDto = SessionCreatedResponseDto.fromJson(response);
      if (sessionDto.session.isNotEmpty) {
        _activeSessionId = sessionDto.session;

        var questions = sessionDto.questions
            .map(
              (q) =>
                  SuddenDeathQuestionDto.fromJson(q).toDomain(topicId: topicId),
            )
            .toList();

        // Fallback: If questions list was not populated in session creation, fetch from DB for topic
        if (questions.isEmpty) {
          questions = await getQuestionsForTopic(backendTopic);
        }

        _activeSessionQuestions = questions;
        return _activeSessionId!;
      }
    }

    throw const ServerException(
      'Failed to create sudden death quiz session on backend.',
      'invalid-quiz-session',
    );
  }

  /// Fetches questions for a topic as fallback.
  Future<List<SuddenDeathQuestion>> getQuestionsForTopic(String topicId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.topicQuestions(topicId),
      );
      if (response is Map<String, dynamic>) {
        final topicDto = TopicQuestionsResponseDto.fromJson(response);
        return topicDto.questions
            .map((q) {
              final domainOptions = q.options
                  .map((o) => QuestionOption(id: o.option, text: o.text))
                  .toList();
              return SuddenDeathQuestion(
                id: q.question,
                topicId: topicId,
                prompt: q.prompt,
                points: q.points,
                hint: q.hint,
                correctOptionId:
                    q.correctOption ??
                    (domainOptions.isNotEmpty ? domainOptions.first.id : 'a'),
                options: domainOptions,
              );
            })
            .where((q) => q.options.length >= 2)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Submits an individual evaluated answer to the backend to update session records.
  Future<AnswerResultResponseDto?> evaluateAnswer({
    required String sessionId,
    required String question,
    required String option,
    String? selectedText,
    int timeTakenMs = 1500,
  }) async {
    try {
      final req = EvaluateAnswerRequestDto(
        session: sessionId,
        question: question,
        option: option,
        selectedText: selectedText,
        timeTakenMs: timeTakenMs,
      );
      final response = await _apiClient.post(
        ApiEndpoints.quizEvaluateAnswer,
        body: req.toJson(),
      );
      if (response is Map<String, dynamic>) {
        return AnswerResultResponseDto.fromJson(response);
      }
    } catch (_) {}
    return null;
  }

  /// Finalizes the session on the backend, updating the wallet ledger and profile.
  Future<SessionCompleteResponseDto?> completeSession({
    required String sessionId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.quizCompleteSession,
        body: {'session': sessionId},
      );
      if (response is Map<String, dynamic>) {
        return SessionCompleteResponseDto.fromJson(response);
      }
    } catch (_) {}
    return null;
  }

  /// Connects to the Sudden Death WebSocket endpoint.
  Future<void> connect({
    required String sessionId,
    String? tokenOverride,
  }) async {
    final token = tokenOverride ?? _storage.getString(StorageKeys.authToken);
    if (token == null || token.isEmpty) {
      throw const AuthException(
        'Authentication required to connect to live Sudden Death game.',
        'unauthorized',
      );
    }

    _activeSessionId = sessionId;

    final wsBase = _apiConfig.gameWsUrl;
    final wsUri = Uri.parse(
      '$wsBase?session_id=${Uri.encodeQueryComponent(sessionId)}&token=${Uri.encodeQueryComponent(token)}',
    );

    await _socketClient.connect(wsUri);
  }

  /// Sends a player's answer submission frame.
  void submitAnswer({
    required String question,
    required String option,
    String? selectedText,
    int timeTakenMs = 0,
  }) {
    _socketClient.send(
      WsInboundMessage.submitAnswer(
        question: question,
        option: option,
        selectedText: selectedText,
        timeTakenMs: timeTakenMs,
        session: _activeSessionId,
      ),
    );
  }

  /// Sends a request to use the single-use 50:50 power-up.
  void useFiftyFifty({required String question}) {
    _socketClient.send(
      WsInboundMessage.usePowerUp(
        question: question,
        powerUp: 'fifty_fifty',
        session: _activeSessionId,
      ),
    );
  }

  /// Requests a server-authoritative five-second deadline extension.
  void addTime({required String question}) {
    _socketClient.send(
      WsInboundMessage.usePowerUp(
        question: question,
        powerUp: 'add_time',
        session: _activeSessionId,
      ),
    );
  }

  /// Requests the backend-owned Skip transition for the active question.
  void skipQuestion({required String question}) {
    _socketClient.send(
      WsInboundMessage.usePowerUp(
        question: question,
        powerUp: 'skip',
        session: _activeSessionId,
      ),
    );
  }

  /// Re-synchronizes with the live game session.
  void joinGame() {
    _socketClient.send(WsInboundMessage.joinGame(session: _activeSessionId));
  }

  /// Marks an unfinished session as abandoned on the backend.
  ///
  /// Called when the player leaves a run before `game_over`. Without this the
  /// session would stay `in_progress` until the server's 5-minute inactivity
  /// sweeper collects it, which also means a later session create cannot use
  /// the topic slot.
  ///
  /// Safe to call when the run already finished: the backend answers `409`,
  /// which is treated as success here because the session is already closed.
  Future<void> abandonSession({String? sessionId}) async {
    final session = sessionId ?? _activeSessionId;
    if (session == null || session.isEmpty) return;

    try {
      await _apiClient.post(
        ApiEndpoints.quizAbandonSession,
        body: {'session': session},
      );
    } on ValidationException {
      // 409 (already completed/abandoned) and 400 are both terminal states
      // for the session; nothing left to clean up.
    } on NotFoundException {
      // Session already gone — treat as abandoned.
    }
  }

  /// Closes the WebSocket connection and resets active state.
  Future<void> disconnect([int? code, String? reason]) async {
    await _socketClient.close(code, reason);
    _activeSessionId = null;
  }
}
