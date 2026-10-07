import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/remote/sudden_death_remote_datasource.dart';
import '../../data/datasources/remote/sudden_death_socket_client.dart';
import '../../data/models/sudden_death_ws_dto.dart';
import '../../domain/entities/quiz_result.dart';
import 'quiz_providers.dart';

enum SuddenDeathStatus {
  initial,
  connecting,
  questionActive,
  showingResult,
  transitioning,
  gameOver,
  error,
}

enum SuddenDeathConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
  gameOver,
}

class SuddenDeathViewState {
  final SuddenDeathStatus status;
  final SuddenDeathConnectionStatus connectionStatus;
  final String? sessionId;
  final List<SuddenDeathQuestion> questions;
  final WsQuestionPayload? questionPayload;
  final SuddenDeathQuestion? currentQuestion;
  final int currentIndex;
  final int totalQuestions;
  final int remainingTimeMs;
  final int timeLimitMs;
  final Set<String> hiddenOptionIds;
  final bool fiftyFiftyUsed;
  final bool addTimeUsed;
  final bool isAddTimePending;
  final bool skipUsed;
  final bool hintUsed;
  final WsAnswerResultPayload? lastAnswerResult;
  final int currentStreak;
  final int bestStreak;
  final int currentScore;
  final QuizResult? result;
  final String? errorMessage;
  final bool isSubmitting;
  final String? selectedOptionId;

  const SuddenDeathViewState({
    this.status = SuddenDeathStatus.initial,
    this.connectionStatus = SuddenDeathConnectionStatus.idle,
    this.sessionId,
    this.questions = const [],
    this.questionPayload,
    this.currentQuestion,
    this.currentIndex = 0,
    this.totalQuestions = 10,
    this.remainingTimeMs = 15000,
    this.timeLimitMs = 15000,
    this.hiddenOptionIds = const {},
    this.fiftyFiftyUsed = false,
    this.addTimeUsed = false,
    this.isAddTimePending = false,
    this.skipUsed = false,
    this.hintUsed = false,
    this.lastAnswerResult,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.currentScore = 0,
    this.result,
    this.errorMessage,
    this.isSubmitting = false,
    this.selectedOptionId,
  });

  SuddenDeathViewState copyWith({
    SuddenDeathStatus? status,
    SuddenDeathConnectionStatus? connectionStatus,
    String? sessionId,
    List<SuddenDeathQuestion>? questions,
    WsQuestionPayload? questionPayload,
    SuddenDeathQuestion? currentQuestion,
    int? currentIndex,
    int? totalQuestions,
    int? remainingTimeMs,
    int? timeLimitMs,
    Set<String>? hiddenOptionIds,
    bool? fiftyFiftyUsed,
    bool? addTimeUsed,
    bool? isAddTimePending,
    bool? skipUsed,
    bool? hintUsed,
    WsAnswerResultPayload? lastAnswerResult,
    int? currentStreak,
    int? bestStreak,
    int? currentScore,
    QuizResult? result,
    String? errorMessage,
    bool? isSubmitting,
    String? selectedOptionId,
    bool clearLastAnswerResult = false,
    bool clearErrorMessage = false,
    bool clearSelectedOptionId = false,
  }) {
    return SuddenDeathViewState(
      status: status ?? this.status,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      sessionId: sessionId ?? this.sessionId,
      questions: questions ?? this.questions,
      questionPayload: questionPayload ?? this.questionPayload,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      currentIndex: currentIndex ?? this.currentIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      remainingTimeMs: remainingTimeMs ?? this.remainingTimeMs,
      timeLimitMs: timeLimitMs ?? this.timeLimitMs,
      hiddenOptionIds: hiddenOptionIds ?? this.hiddenOptionIds,
      fiftyFiftyUsed: fiftyFiftyUsed ?? this.fiftyFiftyUsed,
      addTimeUsed: addTimeUsed ?? this.addTimeUsed,
      isAddTimePending: isAddTimePending ?? this.isAddTimePending,
      skipUsed: skipUsed ?? this.skipUsed,
      hintUsed: hintUsed ?? this.hintUsed,
      lastAnswerResult: clearLastAnswerResult
          ? null
          : lastAnswerResult ?? this.lastAnswerResult,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      currentScore: currentScore ?? this.currentScore,
      result: result ?? this.result,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedOptionId: clearSelectedOptionId
          ? null
          : selectedOptionId ?? this.selectedOptionId,
    );
  }
}

final suddenDeathSocketClientProvider =
    Provider.autoDispose<SuddenDeathSocketClient>((ref) {
      final client = IoSuddenDeathSocketClient();
      ref.onDispose(client.close);
      return client;
    });

final suddenDeathDatasourceProvider =
    Provider.autoDispose<SuddenDeathRemoteDatasource>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      final storage = ref.watch(localStorageServiceProvider);
      final apiConfig = ref.watch(apiConfigProvider);
      final socketClient = ref.watch(suddenDeathSocketClientProvider);

      final ds = SuddenDeathRemoteDatasource(
        apiClient: apiClient,
        storage: storage,
        apiConfig: apiConfig,
        socketClient: socketClient,
      );
      ref.onDispose(ds.disconnect);
      return ds;
    });

class SuddenDeathController
    extends
        AutoDisposeFamilyAsyncNotifier<
          SuddenDeathViewState,
          QuizSessionRequest
        > {
  StreamSubscription<WsServerEvent>? _eventsSub;
  late DateTime _startedAt;
  DateTime? _questionDisplayedAt;
  Timer? _addTimeRequestTimer;
  Timer? _answerRequestTimer;
  Completer<WsQuestionPayload>? _firstQuestionCompleter;
  Completer<WsQuestionPayload>? _resyncQuestionCompleter;
  Future<void>? _reconnectTask;
  Future<void>? _resyncTask;
  int _connectionGeneration = 0;
  bool _disposed = false;

  static const _reconnectDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  void _debugLog(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    developer.log(
      '[SD] $message',
      name: 'SuddenDeathController',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _maskedSessionId(String sessionId) {
    if (sessionId.length <= 8) return sessionId;
    return '${sessionId.substring(0, 4)}...${sessionId.substring(sessionId.length - 4)}';
  }

  @override
  Future<SuddenDeathViewState> build(QuizSessionRequest request) async {
    _startedAt = DateTime.now();
    _addTimeRequestTimer?.cancel();
    _addTimeRequestTimer = null;
    _answerRequestTimer?.cancel();
    _answerRequestTimer = null;
    _firstQuestionCompleter = Completer<WsQuestionPayload>();
    _resyncQuestionCompleter = null;
    _reconnectTask = null;
    _resyncTask = null;
    _connectionGeneration++;
    _disposed = false;

    final ds = ref.read(suddenDeathDatasourceProvider);

    ref.onDispose(() {
      _disposed = true;
      _addTimeRequestTimer?.cancel();
      _addTimeRequestTimer = null;
      _answerRequestTimer?.cancel();
      _answerRequestTimer = null;
      _eventsSub?.cancel();
      _eventsSub = null;
      _resyncQuestionCompleter = null;
      _connectionGeneration++;
      _reconnectTask = null;
      _resyncTask = null;
    });

    final storage = ref.read(localStorageServiceProvider);
    final token = storage.getString(StorageKeys.authToken);
    if (token == null || token.isEmpty) {
      return const SuddenDeathViewState(
        status: SuddenDeathStatus.error,
        errorMessage: 'Please log in to play Sudden Death mode.',
      );
    }

    try {
      final sessionId = await ds.createSession(
        topicId: request.topicId,
        questionCount: 10,
      );
      _debugLog('session created: ${_maskedSessionId(sessionId)}');

      // Subscribe before connecting because AttachPlayer immediately emits the
      // server-authoritative active question.
      _eventsSub = ds.events.listen(
        _onServerEvent,
        onError: (Object error) {
          final completer = _firstQuestionCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      await ds.connect(sessionId: sessionId);
      final firstPayload = await _firstQuestionCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const ServerException(
          'The server did not provide the active Sudden Death question.',
          'sudden-death-question-timeout',
        ),
      );
      final firstQuestion = firstPayload.toDomain(request.topicId);
      _questionDisplayedAt = DateTime.now();

      return SuddenDeathViewState(
        status: SuddenDeathStatus.questionActive,
        connectionStatus: SuddenDeathConnectionStatus.connected,
        sessionId: sessionId,
        questions: [firstQuestion],
        questionPayload: firstPayload,
        currentQuestion: firstQuestion,
        currentIndex: firstPayload.questionNumber - 1,
        totalQuestions: firstPayload.totalQuestions,
        remainingTimeMs: firstPayload.remainingTimeMs,
        timeLimitMs: firstPayload.timeLimitMs,
        addTimeUsed: firstPayload.addTimeUsed,
        skipUsed: firstPayload.skipUsed,
      );
    } on AppException catch (e) {
      return SuddenDeathViewState(
        status: SuddenDeathStatus.error,
        connectionStatus: SuddenDeathConnectionStatus.failed,
        errorMessage: e.message,
      );
    } catch (e) {
      return SuddenDeathViewState(
        status: SuddenDeathStatus.error,
        connectionStatus: SuddenDeathConnectionStatus.failed,
        errorMessage: 'Failed to start Sudden Death session: $e',
      );
    }
  }

  void _onServerEvent(WsServerEvent event) {
    switch (event) {
      case WsQuestionEvent(:final payload):
        _debugLog(
          'question received: ${payload.question} '
          '(remaining_time_ms=${payload.remainingTimeMs})',
        );
        final firstQuestion = _firstQuestionCompleter;
        if (firstQuestion != null && !firstQuestion.isCompleted) {
          firstQuestion.complete(payload);
          return;
        }

        final current = state.valueOrNull;
        if (current == null || current.status == SuddenDeathStatus.gameOver) {
          return;
        }

        final currentNumber = current.currentIndex + 1;
        if (payload.questionNumber < currentNumber) {
          final resync = _resyncQuestionCompleter;
          if (resync != null && !resync.isCompleted) {
            resync.completeError(
              const ServerException(
                'The server returned a stale Sudden Death question.',
                'stale_question',
              ),
            );
          }
          return;
        }

        final question = payload.toDomain(arg.topicId);
        final isSameQuestion =
            current.currentQuestion?.id.toLowerCase() ==
            payload.question.toLowerCase();
        final serverAcceptedPaidPowerUp =
            (!current.addTimeUsed && payload.addTimeUsed) ||
            (!current.skipUsed && payload.skipUsed);
        final questions =
            current.questions.any(
              (item) => item.id.toLowerCase() == payload.question.toLowerCase(),
            )
            ? current.questions
            : [...current.questions, question];

        _answerRequestTimer?.cancel();
        _answerRequestTimer = null;
        if (payload.addTimeUsed) {
          _addTimeRequestTimer?.cancel();
          _addTimeRequestTimer = null;
        }
        _questionDisplayedAt = DateTime.now();
        state = AsyncValue.data(
          current.copyWith(
            status: SuddenDeathStatus.questionActive,
            connectionStatus: SuddenDeathConnectionStatus.connected,
            questions: questions,
            questionPayload: payload,
            currentQuestion: question,
            currentIndex: payload.questionNumber - 1,
            totalQuestions: payload.totalQuestions,
            remainingTimeMs: payload.remainingTimeMs,
            timeLimitMs: payload.timeLimitMs,
            hiddenOptionIds: const {},
            addTimeUsed: payload.addTimeUsed,
            isAddTimePending: isSameQuestion && !payload.addTimeUsed
                ? current.isAddTimePending
                : false,
            skipUsed: payload.skipUsed,
            isSubmitting: false,
            clearLastAnswerResult: true,
            clearSelectedOptionId: true,
            clearErrorMessage: true,
          ),
        );
        final resync = _resyncQuestionCompleter;
        if (resync != null && !resync.isCompleted) {
          _debugLog('resync complete');
          resync.complete(payload);
        }
        if (serverAcceptedPaidPowerUp) {
          ref.invalidate(walletControllerProvider);
        }
      case WsPowerUpResultEvent(:final payload):
        final current = state.valueOrNull;
        if (current != null &&
            payload.powerUp == 'add_time' &&
            current.status == SuddenDeathStatus.questionActive &&
            current.currentQuestion?.id.toLowerCase() ==
                payload.question.toLowerCase()) {
          _addTimeRequestTimer?.cancel();
          _addTimeRequestTimer = null;
          state = AsyncValue.data(
            current.copyWith(
              remainingTimeMs: payload.remainingTimeMs,
              addTimeUsed: true,
              isAddTimePending: false,
            ),
          );
          _debugLog(
            '+5 confirmed: remaining_time_ms=${payload.remainingTimeMs}',
          );
          ref.invalidate(walletControllerProvider);
        }
      case WsAnswerResultEvent(:final payload):
        final current = state.valueOrNull;
        if (current == null ||
            current.status == SuddenDeathStatus.gameOver ||
            current.currentQuestion?.id.toLowerCase() !=
                payload.question.toLowerCase()) {
          return;
        }

        _answerRequestTimer?.cancel();
        _answerRequestTimer = null;
        _addTimeRequestTimer?.cancel();
        _addTimeRequestTimer = null;
        final streak = payload.isCorrect ? current.currentStreak + 1 : 0;
        state = AsyncValue.data(
          current.copyWith(
            status: SuddenDeathStatus.showingResult,
            lastAnswerResult: payload,
            currentStreak: streak,
            bestStreak: streak > current.bestStreak
                ? streak
                : current.bestStreak,
            currentScore: payload.yourScore,
            skipUsed: current.skipUsed || payload.isSkipped,
            isSubmitting: false,
            isAddTimePending: false,
            clearErrorMessage: true,
            clearSelectedOptionId: payload.isSkipped || payload.isTimeout,
          ),
        );
        _debugLog('answer_result received: ${payload.question}');
        if (payload.isSkipped) {
          ref.invalidate(walletControllerProvider);
        }
      case WsGameOverEvent(:final payload):
        final current = state.valueOrNull;
        if (current != null && current.status != SuddenDeathStatus.gameOver) {
          final resync = _resyncQuestionCompleter;
          if (resync != null && !resync.isCompleted) {
            resync.completeError(
              const ServerException(
                'The Sudden Death session has ended.',
                'session_ended',
              ),
            );
          }
          final authUser = ref.read(authControllerProvider).valueOrNull;
          final result = payload.toQuizResult(
            sessionId: current.sessionId ?? 'session-${arg.topicId}',
            userId: authUser?.id,
            subjectId: arg.subjectId,
            chapterId: arg.chapterId,
            topicId: arg.topicId,
            startedAt: _startedAt,
            completedAt: DateTime.now(),
          );
          ref.invalidate(profileControllerProvider);
          ref.invalidate(walletControllerProvider);
          _answerRequestTimer?.cancel();
          _answerRequestTimer = null;
          _addTimeRequestTimer?.cancel();
          _addTimeRequestTimer = null;
          state = AsyncValue.data(
            current.copyWith(
              status: SuddenDeathStatus.gameOver,
              connectionStatus: SuddenDeathConnectionStatus.gameOver,
              result: result,
              isSubmitting: false,
              isAddTimePending: false,
            ),
          );
          _debugLog('game_over');
        }
      case WsErrorEvent(:final payload):
        if (payload.code == 'socket_error' || payload.code == 'socket_closed') {
          _debugLog('socket disconnected: ${payload.message}');
          final firstQuestion = _firstQuestionCompleter;
          if (firstQuestion != null && !firstQuestion.isCompleted) {
            firstQuestion.completeError(
              ServerException(payload.message, payload.code),
            );
            return;
          }
          unawaited(_startReconnect());
          return;
        }
        final firstQuestion = _firstQuestionCompleter;
        if (firstQuestion != null && !firstQuestion.isCompleted) {
          firstQuestion.completeError(
            ServerException(payload.message, payload.code),
          );
          return;
        }
        final resync = _resyncQuestionCompleter;
        if (resync != null && !resync.isCompleted) {
          resync.completeError(ServerException(payload.message, payload.code));
        }
        if (payload.code != 'transition_in_progress') {
          final current = state.valueOrNull;
          if (current != null) {
            _answerRequestTimer?.cancel();
            _answerRequestTimer = null;
            _addTimeRequestTimer?.cancel();
            _addTimeRequestTimer = null;
            state = AsyncValue.data(
              current.copyWith(
                errorMessage: payload.message,
                isAddTimePending: false,
                isSubmitting: false,
              ),
            );
          }
        }
      default:
        break;
    }
  }

  Future<void> _startReconnect() {
    if (_disposed) return Future<void>.value();
    final existing = _reconnectTask;
    if (existing != null) return existing;

    late final Future<void> task;
    task = _runReconnect().whenComplete(() {
      if (identical(_reconnectTask, task)) {
        _reconnectTask = null;
      }
    });
    _reconnectTask = task;
    return task;
  }

  Future<void> _runReconnect() async {
    final initial = state.valueOrNull;
    final sessionId = initial?.sessionId;
    if (initial == null ||
        sessionId == null ||
        sessionId.isEmpty ||
        initial.status == SuddenDeathStatus.gameOver ||
        initial.status == SuddenDeathStatus.error) {
      return;
    }

    final generation = _connectionGeneration;
    final datasource = ref.read(suddenDeathDatasourceProvider);
    state = AsyncValue.data(
      initial.copyWith(
        connectionStatus: SuddenDeathConnectionStatus.reconnecting,
        isAddTimePending: false,
        isSubmitting: false,
      ),
    );

    for (var attempt = 0; attempt < _reconnectDelays.length; attempt++) {
      if (_disposed || generation != _connectionGeneration) return;
      final delay = _reconnectDelays[attempt];
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (_disposed || generation != _connectionGeneration) return;

      final current = state.valueOrNull;
      if (current == null || current.status == SuddenDeathStatus.gameOver) {
        return;
      }

      final resync = Completer<WsQuestionPayload>();
      _resyncQuestionCompleter = resync;
      _debugLog('reconnecting (attempt ${attempt + 1})');
      try {
        await datasource.connect(sessionId: sessionId);
        await resync.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw const ServerException(
            'The active question could not be synchronized.',
            'sudden-death-resync-timeout',
          ),
        );
        if (_disposed || generation != _connectionGeneration) return;
        final synchronized = state.valueOrNull;
        if (synchronized != null &&
            synchronized.status != SuddenDeathStatus.gameOver) {
          state = AsyncValue.data(
            synchronized.copyWith(
              connectionStatus: SuddenDeathConnectionStatus.connected,
              clearErrorMessage: true,
            ),
          );
        }
        return;
      } catch (error, stackTrace) {
        _debugLog(
          'reconnect attempt ${attempt + 1} failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
        final latest = state.valueOrNull;
        if (latest == null || latest.status == SuddenDeathStatus.gameOver) {
          return;
        }
        state = AsyncValue.data(
          latest.copyWith(
            connectionStatus: SuddenDeathConnectionStatus.disconnected,
          ),
        );
      } finally {
        if (identical(_resyncQuestionCompleter, resync)) {
          _resyncQuestionCompleter = null;
        }
      }
    }

    if (_disposed || generation != _connectionGeneration) return;
    final latest = state.valueOrNull;
    if (latest != null && latest.status != SuddenDeathStatus.gameOver) {
      state = AsyncValue.data(
        latest.copyWith(
          connectionStatus: SuddenDeathConnectionStatus.failed,
          errorMessage: 'The live game connection is unavailable.',
        ),
      );
    }
  }

  /// Confirms the socket is connected and the displayed question has been
  /// authoritatively resynchronized before a paid action may debit the wallet.
  Future<bool> ensureLiveConnection() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.currentQuestion == null) {
      return false;
    }

    final activeResync = _resyncTask;
    if (activeResync != null) {
      await activeResync;
    }

    final datasource = ref.read(suddenDeathDatasourceProvider);
    final latestBeforeReconnect = state.valueOrNull;
    if (!datasource.isConnected ||
        latestBeforeReconnect?.connectionStatus !=
            SuddenDeathConnectionStatus.connected) {
      await _startReconnect();
    }

    if (_disposed) return false;
    final synchronized = state.valueOrNull;
    final isReady =
        datasource.isConnected &&
        synchronized?.connectionStatus ==
            SuddenDeathConnectionStatus.connected &&
        synchronized?.status == SuddenDeathStatus.questionActive &&
        synchronized?.currentQuestion?.id.toLowerCase() ==
            current.currentQuestion?.id.toLowerCase();
    if (!isReady && synchronized != null) {
      state = AsyncValue.data(
        synchronized.copyWith(
          errorMessage: 'The live game connection is unavailable.',
        ),
      );
    }
    return isReady;
  }

  /// Revalidates the same active session when Android returns to foreground.
  Future<void> resyncAfterResume() => _startAuthoritativeResync('app resumed');

  Future<void> _startAuthoritativeResync(String reason) {
    if (_disposed) return Future<void>.value();
    final existing = _resyncTask;
    if (existing != null) return existing;

    late final Future<void> task;
    task = _runAuthoritativeResync(reason).whenComplete(() {
      if (identical(_resyncTask, task)) {
        _resyncTask = null;
      }
    });
    _resyncTask = task;
    return task;
  }

  Future<void> _runAuthoritativeResync(String reason) async {
    final current = state.valueOrNull;
    if (_disposed ||
        current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.sessionId == null) {
      return;
    }

    final datasource = ref.read(suddenDeathDatasourceProvider);
    if (!datasource.isConnected) {
      await _startReconnect();
      return;
    }

    final resync = Completer<WsQuestionPayload>();
    _resyncQuestionCompleter = resync;
    state = AsyncValue.data(
      current.copyWith(
        connectionStatus: SuddenDeathConnectionStatus.reconnecting,
      ),
    );
    try {
      _debugLog('$reason; requesting authoritative resync');
      datasource.joinGame();
      await resync.future.timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      _debugLog(
        '$reason resync failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      await _startReconnect();
    } finally {
      if (identical(_resyncQuestionCompleter, resync)) {
        _resyncQuestionCompleter = null;
      }
    }
  }

  /// The visual clock never decides timeout. At zero it requests an
  /// authoritative resync, including when a mobile socket is half-open.
  void handleDisplayedTimerExpired() {
    unawaited(_startAuthoritativeResync('displayed timer reached zero'));
  }

  bool _hasCurrentAuthoritativeQuestion(SuddenDeathViewState current) {
    final questionId = current.currentQuestion?.id.toLowerCase();
    final authoritativeId = current.questionPayload?.question.toLowerCase();
    final matches =
        questionId != null &&
        authoritativeId != null &&
        questionId == authoritativeId;
    assert(
      matches,
      'Displayed Sudden Death question must match the latest server frame.',
    );
    return matches;
  }

  /// Requests the server to extend the active question deadline by five
  /// seconds. The displayed countdown changes only after power_up_result.
  Future<void> addFiveSeconds() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.isAddTimePending ||
        current.addTimeUsed ||
        current.currentQuestion == null ||
        !_hasCurrentAuthoritativeQuestion(current)) {
      return;
    }

    final datasource = ref.read(suddenDeathDatasourceProvider);
    if (!await ensureLiveConnection()) return;

    if (_disposed) return;
    final latest = state.valueOrNull;
    if (latest == null ||
        latest.status != SuddenDeathStatus.questionActive ||
        latest.currentQuestion?.id.toLowerCase() !=
            current.currentQuestion?.id.toLowerCase() ||
        latest.addTimeUsed) {
      return;
    }

    state = AsyncValue.data(
      latest.copyWith(isAddTimePending: true, clearErrorMessage: true),
    );
    datasource.addTime(question: latest.currentQuestion!.id);
    _debugLog('+5 request sent');
    _addTimeRequestTimer?.cancel();
    _addTimeRequestTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      final pending = state.valueOrNull;
      if (pending == null || !pending.isAddTimePending) return;
      state = AsyncValue.data(
        pending.copyWith(
          isAddTimePending: false,
          errorMessage: 'The add-time request could not be confirmed.',
        ),
      );
      unawaited(_startAuthoritativeResync('add-time confirmation timed out'));
    });
  }

  /// Sends the answer for the server's currently active question.
  ///
  /// This deliberately does not grade or advance locally. The current
  /// question remains active until the backend returns `answer_result`, and
  /// the index changes only when the backend sends the next `question` frame.
  void submitAnswer(String option) {
    final current = state.valueOrNull;
    if (current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.currentQuestion == null ||
        !_hasCurrentAuthoritativeQuestion(current)) {
      return;
    }

    final question = current.currentQuestion!;
    final normalizedOption = option.toLowerCase();
    final selected = question.options.where(
      (item) => item.id.toLowerCase() == normalizedOption,
    );
    if (selected.isEmpty) return;

    final datasource = ref.read(suddenDeathDatasourceProvider);
    if (!datasource.isConnected) {
      state = AsyncValue.data(
        current.copyWith(
          connectionStatus: SuddenDeathConnectionStatus.disconnected,
          errorMessage: 'The live game connection is unavailable.',
        ),
      );
      unawaited(_startReconnect());
      return;
    }

    final elapsedMs = _questionDisplayedAt == null
        ? 0
        : DateTime.now().difference(_questionDisplayedAt!).inMilliseconds;
    state = AsyncValue.data(
      current.copyWith(
        isSubmitting: true,
        selectedOptionId: normalizedOption,
        clearErrorMessage: true,
      ),
    );
    datasource.submitAnswer(
      question: question.id,
      option: normalizedOption,
      selectedText: selected.first.text,
      timeTakenMs: elapsedMs,
    );
    _debugLog('answer sent: ${question.id}');
    _startAnswerConfirmationTimer(question.id);
  }

  /// Requests Skip for the server's current question. The next question is
  /// rendered only after the backend confirms the skip and emits `question`.
  void skipQuestion() {
    final current = state.valueOrNull;
    if (current == null ||
        current.skipUsed ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.currentQuestion == null ||
        !_hasCurrentAuthoritativeQuestion(current)) {
      return;
    }

    final datasource = ref.read(suddenDeathDatasourceProvider);
    if (!datasource.isConnected) {
      state = AsyncValue.data(
        current.copyWith(
          connectionStatus: SuddenDeathConnectionStatus.disconnected,
          errorMessage: 'The live game connection is unavailable.',
        ),
      );
      unawaited(_startReconnect());
      return;
    }

    final questionId = current.currentQuestion!.id;
    state = AsyncValue.data(
      current.copyWith(isSubmitting: true, clearErrorMessage: true),
    );
    datasource.skipQuestion(question: questionId);
    _debugLog('skip request sent: $questionId');
    _startAnswerConfirmationTimer(questionId);
  }

  void _startAnswerConfirmationTimer(String questionId) {
    _answerRequestTimer?.cancel();
    _answerRequestTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      final current = state.valueOrNull;
      if (current == null ||
          !current.isSubmitting ||
          current.currentQuestion?.id.toLowerCase() !=
              questionId.toLowerCase()) {
        return;
      }
      state = AsyncValue.data(
        current.copyWith(
          isSubmitting: false,
          errorMessage: 'The answer could not be confirmed by the server.',
        ),
      );
      unawaited(_startAuthoritativeResync('answer confirmation timed out'));
    });
  }

  /// Abandons an unfinished run.
  Future<void> abandon() async {
    _connectionGeneration++;
    _answerRequestTimer?.cancel();
    _addTimeRequestTimer?.cancel();
    final ds = ref.read(suddenDeathDatasourceProvider);
    final current = state.valueOrNull;
    if (current?.result == null && current?.sessionId != null) {
      await ds.abandonSession(sessionId: current?.sessionId);
    }
  }

  /// Retry session creation and game start.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

final suddenDeathControllerProvider =
    AutoDisposeAsyncNotifierProvider.family<
      SuddenDeathController,
      SuddenDeathViewState,
      QuizSessionRequest
    >(SuddenDeathController.new);
