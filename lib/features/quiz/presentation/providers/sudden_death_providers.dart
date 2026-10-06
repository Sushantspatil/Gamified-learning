import 'dart:async';
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

class SuddenDeathViewState {
  final SuddenDeathStatus status;
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
  }) {
    return SuddenDeathViewState(
      status: status ?? this.status,
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
      lastAnswerResult: lastAnswerResult ?? this.lastAnswerResult,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      currentScore: currentScore ?? this.currentScore,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
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

class SuddenDeathRecord {
  final SuddenDeathQuestion question;
  final String option;
  final String? selectedText;
  final bool isCorrect;
  final bool isSkipped;
  final bool isTimeout;
  final int timeTakenMs;

  const SuddenDeathRecord({
    required this.question,
    required this.option,
    this.selectedText,
    required this.isCorrect,
    required this.isSkipped,
    required this.isTimeout,
    required this.timeTakenMs,
  });
}

class SuddenDeathController
    extends
        AutoDisposeFamilyAsyncNotifier<
          SuddenDeathViewState,
          QuizSessionRequest
        > {
  final List<SuddenDeathRecord> _recordedAnswers = [];
  StreamSubscription<WsServerEvent>? _eventsSub;
  late DateTime _startedAt;
  DateTime? _questionDisplayedAt;
  Timer? _transitionTimer;
  Timer? _addTimeRequestTimer;
  bool _disposed = false;

  @override
  Future<SuddenDeathViewState> build(QuizSessionRequest request) async {
    _startedAt = DateTime.now();
    _recordedAnswers.clear();
    _transitionTimer?.cancel();
    _transitionTimer = null;
    _addTimeRequestTimer?.cancel();
    _addTimeRequestTimer = null;
    _disposed = false;

    final ds = ref.read(suddenDeathDatasourceProvider);

    ref.onDispose(() {
      _disposed = true;
      _transitionTimer?.cancel();
      _transitionTimer = null;
      _addTimeRequestTimer?.cancel();
      _addTimeRequestTimer = null;
      _eventsSub?.cancel();
      _eventsSub = null;
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

      var questions = ds.activeSessionQuestions;
      if (questions == null || questions.isEmpty) {
        questions = await ds.getQuestionsForTopic(request.topicId);
      }

      if (questions.isEmpty) {
        return const SuddenDeathViewState(
          status: SuddenDeathStatus.error,
          errorMessage: 'No questions available for the selected topic.',
        );
      }

      _questionDisplayedAt = DateTime.now();

      // Listen to server events if WebSocket connects (for backward compatibility / resync)
      _eventsSub = ds.events.listen(
        _onServerEvent,
        onError: (Object error) {
          // Non-fatal if client-side execution is driving
        },
      );

      // Best-effort socket connect for live sync / monitoring without blocking gameplay
      unawaited(ds.connect(sessionId: sessionId).catchError((_) {}));

      final firstQ = questions.first;
      return SuddenDeathViewState(
        status: SuddenDeathStatus.questionActive,
        sessionId: sessionId,
        questions: questions,
        currentQuestion: firstQ,
        currentIndex: 0,
        totalQuestions: questions.length,
        remainingTimeMs: 15000,
        timeLimitMs: 15000,
      );
    } on AppException catch (e) {
      return SuddenDeathViewState(
        status: SuddenDeathStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return SuddenDeathViewState(
        status: SuddenDeathStatus.error,
        errorMessage: 'Failed to start Sudden Death session: $e',
      );
    }
  }

  void _onServerEvent(WsServerEvent event) {
    // If server pushes game over or error, we integrate it
    switch (event) {
      case WsQuestionEvent(:final payload):
        final current = state.valueOrNull;
        if (current != null &&
            current.status == SuddenDeathStatus.questionActive &&
            current.currentQuestion?.id.toLowerCase() ==
                payload.question.toLowerCase()) {
          state = AsyncValue.data(
            current.copyWith(
              questionPayload: payload,
              remainingTimeMs: payload.remainingTimeMs,
              timeLimitMs: payload.timeLimitMs,
              addTimeUsed: payload.addTimeUsed,
              isAddTimePending: payload.addTimeUsed
                  ? false
                  : current.isAddTimePending,
            ),
          );
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
        }
      case WsAnswerResultEvent(:final payload):
        final current = state.valueOrNull;
        if (payload.isTimeout &&
            current != null &&
            current.status == SuddenDeathStatus.questionActive &&
            current.currentQuestion?.id.toLowerCase() ==
                payload.question.toLowerCase()) {
          _addTimeRequestTimer?.cancel();
          _addTimeRequestTimer = null;
          handleTimeout();
        }
      case WsGameOverEvent(:final payload):
        final current = state.valueOrNull;
        if (current != null && current.status != SuddenDeathStatus.gameOver) {
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
          state = AsyncValue.data(
            current.copyWith(
              status: SuddenDeathStatus.gameOver,
              result: result,
              isSubmitting: false,
            ),
          );
        }
      case WsErrorEvent(:final payload):
        if (payload.code != 'transition_in_progress') {
          final current = state.valueOrNull;
          if (current != null) {
            _addTimeRequestTimer?.cancel();
            _addTimeRequestTimer = null;
            state = AsyncValue.data(
              current.copyWith(
                errorMessage: payload.message,
                isAddTimePending: false,
              ),
            );
          }
        }
      default:
        break;
    }
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
        current.currentQuestion == null) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isAddTimePending: true));

    final datasource = ref.read(suddenDeathDatasourceProvider);
    if (!datasource.isConnected) {
      final sessionId = current.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        state = AsyncValue.data(
          current.copyWith(
            errorMessage:
                'Unable to add time without an active live game session.',
          ),
        );
        return;
      }
      try {
        await datasource.connect(sessionId: sessionId);
      } catch (_) {
        if (_disposed) return;
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncValue.data(
            latest.copyWith(
              isAddTimePending: false,
              errorMessage:
                  'Unable to add time while the live game connection is unavailable.',
            ),
          );
        }
        return;
      }
    }

    if (_disposed) return;
    final latest = state.valueOrNull;
    if (latest == null ||
        latest.status != SuddenDeathStatus.questionActive ||
        latest.currentQuestion?.id != current.currentQuestion?.id ||
        !latest.isAddTimePending) {
      return;
    }

    datasource.addTime(question: current.currentQuestion!.id);
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
    });
  }

  /// Instant, zero-latency answer submission evaluated locally.
  void submitAnswer(String option) {
    final current = state.valueOrNull;
    if (current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.currentQuestion == null) {
      return;
    }

    final question = current.currentQuestion!;
    final now = DateTime.now();
    final elapsedMs = _questionDisplayedAt != null
        ? now.difference(_questionDisplayedAt!).inMilliseconds
        : 1500;

    String? selectedText;
    for (final opt in question.options) {
      if (opt.id.toLowerCase() == option.toLowerCase()) {
        selectedText = opt.text;
        break;
      }
    }

    final isCorrect =
        option.toLowerCase() == question.correctOptionId.toLowerCase();

    _recordedAnswers.add(
      SuddenDeathRecord(
        question: question,
        option: option.toLowerCase(),
        selectedText: selectedText,
        isCorrect: isCorrect,
        isSkipped: false,
        isTimeout: false,
        timeTakenMs: elapsedMs,
      ),
    );

    if (isCorrect) {
      final newStreak = current.currentStreak + 1;
      final bestStreak = newStreak > current.bestStreak
          ? newStreak
          : current.bestStreak;
      final newScore = current.currentScore + 10;

      final answerResult = WsAnswerResultPayload(
        question: question.id,
        option: option.toLowerCase(),
        correctOption: question.correctOptionId.toLowerCase(),
        isCorrect: true,
        isSkipped: false,
        isTimeout: false,
        explanation: question.hint,
        pointsEarned: 10,
        coinsEarned: 0,
        yourScore: newScore,
      );

      state = AsyncValue.data(
        current.copyWith(
          status: SuddenDeathStatus.showingResult,
          lastAnswerResult: answerResult,
          currentStreak: newStreak,
          bestStreak: bestStreak,
          currentScore: newScore,
          selectedOptionId: option.toLowerCase(),
        ),
      );

      _transitionTimer?.cancel();
      _transitionTimer = Timer(const Duration(milliseconds: 700), () {
        if (_disposed) return;
        final cur = state.valueOrNull;
        if (cur == null) return;

        final nextIndex = cur.currentIndex + 1;
        if (nextIndex < cur.questions.length) {
          _questionDisplayedAt = DateTime.now();
          state = AsyncValue.data(
            cur.copyWith(
              status: SuddenDeathStatus.questionActive,
              currentIndex: nextIndex,
              currentQuestion: cur.questions[nextIndex],
              hiddenOptionIds: const {},
              selectedOptionId: null,
              lastAnswerResult: null,
              remainingTimeMs: 15000,
              addTimeUsed: false,
              isAddTimePending: false,
            ),
          );
        } else {
          // Survived all questions!
          _finalizeSession(isEliminated: false, isTimeout: false);
        }
      });
    } else {
      // Wrong answer in Sudden Death -> Eliminated!
      final answerResult = WsAnswerResultPayload(
        question: question.id,
        option: option.toLowerCase(),
        correctOption: question.correctOptionId.toLowerCase(),
        isCorrect: false,
        isSkipped: false,
        isTimeout: false,
        explanation: question.hint,
        pointsEarned: 0,
        coinsEarned: 0,
        yourScore: current.currentScore,
      );

      state = AsyncValue.data(
        current.copyWith(
          status: SuddenDeathStatus.showingResult,
          lastAnswerResult: answerResult,
          currentStreak: 0,
          selectedOptionId: option.toLowerCase(),
        ),
      );

      _transitionTimer?.cancel();
      _transitionTimer = Timer(const Duration(milliseconds: 1350), () {
        if (_disposed) return;
        _finalizeSession(isEliminated: true, isTimeout: false);
      });
    }
  }

  /// Instant local handling when the countdown reaches 0.
  void handleTimeout() {
    final current = state.valueOrNull;
    if (current == null ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.currentQuestion == null) {
      return;
    }

    final question = current.currentQuestion!;
    _recordedAnswers.add(
      SuddenDeathRecord(
        question: question,
        option: '__timeout__',
        isCorrect: false,
        isSkipped: false,
        isTimeout: true,
        timeTakenMs: 15000,
      ),
    );

    final answerResult = WsAnswerResultPayload(
      question: question.id,
      option: '',
      correctOption: question.correctOptionId.toLowerCase(),
      isCorrect: false,
      isSkipped: false,
      isTimeout: true,
      explanation: question.hint,
      pointsEarned: 0,
      coinsEarned: 0,
      yourScore: current.currentScore,
    );

    state = AsyncValue.data(
      current.copyWith(
        status: SuddenDeathStatus.showingResult,
        lastAnswerResult: answerResult,
        currentStreak: 0,
      ),
    );

    _transitionTimer?.cancel();
    _transitionTimer = Timer(const Duration(milliseconds: 1350), () {
      if (_disposed) return;
      _finalizeSession(isEliminated: true, isTimeout: true);
    });
  }

  /// Instant client-side 50:50 power-up hiding 2 incorrect options.
  void useFiftyFifty() {
    final current = state.valueOrNull;
    if (current == null ||
        current.fiftyFiftyUsed ||
        current.currentQuestion == null) {
      return;
    }

    final question = current.currentQuestion!;
    final correct = question.correctOptionId.toLowerCase();
    final wrongOptions = question.options
        .where((opt) => opt.id.toLowerCase() != correct)
        .map((opt) => opt.id.toLowerCase())
        .toList();

    wrongOptions.shuffle();
    final toHide = wrongOptions.take(2).toSet();

    state = AsyncValue.data(
      current.copyWith(
        fiftyFiftyUsed: true,
        hiddenOptionIds: {...current.hiddenOptionIds, ...toHide},
      ),
    );
  }

  /// Instant client-side Skip power-up.
  void skipQuestion() {
    final current = state.valueOrNull;
    if (current == null ||
        current.skipUsed ||
        current.status != SuddenDeathStatus.questionActive ||
        current.isSubmitting ||
        current.currentQuestion == null) {
      return;
    }

    final question = current.currentQuestion!;
    _recordedAnswers.add(
      SuddenDeathRecord(
        question: question,
        option: 'skip',
        isCorrect: false,
        isSkipped: true,
        isTimeout: false,
        timeTakenMs: 1000,
      ),
    );

    final nextIndex = current.currentIndex + 1;
    if (nextIndex < current.questions.length) {
      _questionDisplayedAt = DateTime.now();
      state = AsyncValue.data(
        current.copyWith(
          skipUsed: true,
          currentStreak: 0,
          currentIndex: nextIndex,
          currentQuestion: current.questions[nextIndex],
          hiddenOptionIds: const {},
          selectedOptionId: null,
          lastAnswerResult: null,
          remainingTimeMs: 15000,
          addTimeUsed: false,
          isAddTimePending: false,
        ),
      );
    } else {
      _finalizeSession(isEliminated: false, isTimeout: false);
    }
  }

  /// Instant client-side Hint revelation.
  void revealHint() {
    final current = state.valueOrNull;
    if (current == null || current.hintUsed) return;
    state = AsyncValue.data(current.copyWith(hintUsed: true));
  }

  /// Finalizes the Sudden Death session on the backend.
  Future<void> _finalizeSession({
    required bool isEliminated,
    required bool isTimeout,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.status == SuddenDeathStatus.gameOver) return;

    state = AsyncValue.data(current.copyWith(isSubmitting: true));

    final ds = ref.read(suddenDeathDatasourceProvider);
    final sessionId = current.sessionId;

    if (sessionId != null && sessionId.isNotEmpty) {
      // 1. Submit all answered records sequentially to backend
      for (final rec in _recordedAnswers) {
        await ds.evaluateAnswer(
          sessionId: sessionId,
          question: rec.question.id,
          option: rec.option,
          selectedText: rec.selectedText,
          timeTakenMs: rec.timeTakenMs,
        );
      }

      // 2. Finalize session on backend to award coins, XP, gems, and update profile/wallet
      final completeRes = await ds.completeSession(sessionId: sessionId);

      ref.invalidate(profileControllerProvider);
      ref.invalidate(walletControllerProvider);

      final authUser = ref.read(authControllerProvider).valueOrNull;
      final correctCount = _recordedAnswers.where((r) => r.isCorrect).length;
      final finalScore = correctCount * 10;
      final xpAwarded = completeRes?.xpAwarded ?? (10 + correctCount * 5);
      final coinsAwarded = completeRes?.coinsAwarded ?? (5 + correctCount * 2);

      final result = QuizResult(
        sessionId: sessionId,
        userId: authUser?.id,
        subjectId: arg.subjectId,
        chapterId: arg.chapterId,
        topicId: arg.topicId,
        quizType: QuestionType.suddenDeath,
        score: Score(
          earnedPoints: finalScore,
          maxPoints: current.totalQuestions * 10,
          correctCount: correctCount,
          totalCount: current.totalQuestions,
        ),
        records: const [],
        endedEarly: isEliminated || isTimeout,
        streakCount: current.bestStreak,
        xpAwarded: xpAwarded,
        coinsAwarded: coinsAwarded,
        gemsAwarded: completeRes?.gemsAwarded ?? 0,
        didLevelUp: completeRes?.levelUpReward != null,
        rewardBreakdown: QuizRewardBreakdown(
          score: [
            RewardBreakdownItem(key: 'sudden_death_score', amount: finalScore),
          ],
          xp: [RewardBreakdownItem(key: 'xp_earned', amount: xpAwarded)],
          coins: [
            RewardBreakdownItem(key: 'coins_earned', amount: coinsAwarded),
          ],
        ),
        timeTaken: DateTime.now().difference(_startedAt),
        createdAt: DateTime.now(),
      );

      state = AsyncValue.data(
        current.copyWith(
          status: SuddenDeathStatus.gameOver,
          result: result,
          isSubmitting: false,
        ),
      );
      return;
    }

    // Fallback if no sessionId
    final correctCount = _recordedAnswers.where((r) => r.isCorrect).length;
    final finalScore = correctCount * 10;
    final result = QuizResult(
      sessionId: 'local-${DateTime.now().millisecondsSinceEpoch}',
      subjectId: arg.subjectId,
      chapterId: arg.chapterId,
      topicId: arg.topicId,
      quizType: QuestionType.suddenDeath,
      score: Score(
        earnedPoints: finalScore,
        maxPoints: current.totalQuestions * 10,
        correctCount: correctCount,
        totalCount: current.totalQuestions,
      ),
      records: const [],
      endedEarly: isEliminated || isTimeout,
      streakCount: current.bestStreak,
      xpAwarded: 10 + correctCount * 5,
      coinsAwarded: 5 + correctCount * 2,
      gemsAwarded: 0,
      didLevelUp: false,
      rewardBreakdown: QuizRewardBreakdown(
        score: [
          RewardBreakdownItem(key: 'sudden_death_score', amount: finalScore),
        ],
        xp: [
          RewardBreakdownItem(key: 'xp_earned', amount: 10 + correctCount * 5),
        ],
        coins: [
          RewardBreakdownItem(
            key: 'coins_earned',
            amount: 5 + correctCount * 2,
          ),
        ],
      ),
      timeTaken: DateTime.now().difference(_startedAt),
      createdAt: DateTime.now(),
    );

    state = AsyncValue.data(
      current.copyWith(
        status: SuddenDeathStatus.gameOver,
        result: result,
        isSubmitting: false,
      ),
    );
  }

  /// Abandons an unfinished run.
  Future<void> abandon() async {
    _transitionTimer?.cancel();
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
