import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/remote/quiz_remote_datasource.dart';
import '../../domain/entities/match_the_following_models.dart';
import 'quiz_providers.dart';

/// Immutable presentation state for the Match the Following game mode.
@immutable
class MatchTheFollowingViewState extends Equatable {
  final String sessionId;
  final List<MatchBoard> boards;
  final int currentBoardIndex;
  final String? selectedLeftId;
  final Map<String, String> correctMatches; // confirmed correct left_id -> right_id
  final int mistakes;
  final DateTime? boardStartedAt;
  final int remainingMs;
  final bool boardResolved;
  final List<MatchBoardSubmission> boardSubmissions;
  final bool isCompleting;
  final String? completionError;
  final MatchTheFollowingResult? result;
  final String? lastWrongAttemptLeftId;
  final String? lastWrongAttemptRightId;
  final bool isHintVisible;

  const MatchTheFollowingViewState({
    required this.sessionId,
    required this.boards,
    this.currentBoardIndex = 0,
    this.selectedLeftId,
    this.correctMatches = const {},
    this.mistakes = 0,
    this.boardStartedAt,
    this.remainingMs = 25000,
    this.boardResolved = false,
    this.boardSubmissions = const [],
    this.isCompleting = false,
    this.completionError,
    this.result,
    this.lastWrongAttemptLeftId,
    this.lastWrongAttemptRightId,
    this.isHintVisible = false,
  });

  MatchBoard? get currentBoard =>
      boards.isNotEmpty && currentBoardIndex < boards.length
          ? boards[currentBoardIndex]
          : null;

  bool get isLastBoard => currentBoardIndex >= boards.length - 1;

  bool get isLocked =>
      boardResolved || isCompleting || result != null;

  MatchTheFollowingViewState copyWith({
    String? sessionId,
    List<MatchBoard>? boards,
    int? currentBoardIndex,
    String? Function()? selectedLeftId,
    Map<String, String>? correctMatches,
    int? mistakes,
    DateTime? boardStartedAt,
    int? remainingMs,
    bool? boardResolved,
    List<MatchBoardSubmission>? boardSubmissions,
    bool? isCompleting,
    String? Function()? completionError,
    MatchTheFollowingResult? Function()? result,
    String? Function()? lastWrongAttemptLeftId,
    String? Function()? lastWrongAttemptRightId,
    bool? isHintVisible,
  }) {
    return MatchTheFollowingViewState(
      sessionId: sessionId ?? this.sessionId,
      boards: boards ?? this.boards,
      currentBoardIndex: currentBoardIndex ?? this.currentBoardIndex,
      selectedLeftId:
          selectedLeftId != null ? selectedLeftId() : this.selectedLeftId,
      correctMatches: correctMatches ?? this.correctMatches,
      mistakes: mistakes ?? this.mistakes,
      boardStartedAt: boardStartedAt ?? this.boardStartedAt,
      remainingMs: remainingMs ?? this.remainingMs,
      boardResolved: boardResolved ?? this.boardResolved,
      boardSubmissions: boardSubmissions ?? this.boardSubmissions,
      isCompleting: isCompleting ?? this.isCompleting,
      completionError:
          completionError != null ? completionError() : this.completionError,
      result: result != null ? result() : this.result,
      lastWrongAttemptLeftId: lastWrongAttemptLeftId != null
          ? lastWrongAttemptLeftId()
          : this.lastWrongAttemptLeftId,
      lastWrongAttemptRightId: lastWrongAttemptRightId != null
          ? lastWrongAttemptRightId()
          : this.lastWrongAttemptRightId,
      isHintVisible: isHintVisible ?? this.isHintVisible,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        boards,
        currentBoardIndex,
        selectedLeftId,
        correctMatches,
        mistakes,
        boardStartedAt,
        boardResolved,
        boardSubmissions,
        isCompleting,
        completionError,
        result,
        lastWrongAttemptLeftId,
        lastWrongAttemptRightId,
        isHintVisible,
        remainingMs ~/ 1000,
      ];
}

/// Provider managing Match the Following state and gameplay interactions.
final matchTheFollowingControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    MatchTheFollowingController, MatchTheFollowingViewState, QuizSessionRequest>(
  MatchTheFollowingController.new,
);

class MatchTheFollowingController
    extends AutoDisposeFamilyAsyncNotifier<MatchTheFollowingViewState, QuizSessionRequest> {
  Timer? _ticker;
  bool _disposed = false;

  @override
  Future<MatchTheFollowingViewState> build(QuizSessionRequest arg) async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _ticker?.cancel();
    });

    final ds = ref.read(quizDatasourceProvider);
    if (ds is! QuizRemoteDatasource) {
      throw const ValidationException(
        "Match the Following isn't available in mock mode.",
        'not-remote-datasource',
      );
    }

    // Create session using backend default board timer (25s) and 3 boards
    final sessionId = await ds.createSession(
      topicId: arg.topicId,
      gameMode: 'match_the_following',
      questionCount: 3,
    );

    final boards = ds.activeMatchBoards;
    if (boards == null || boards.isEmpty) {
      throw const ValidationException(
        "Match the Following isn't available for this topic yet.",
        'no-match-boards',
      );
    }

    final now = DateTime.now();
    final firstBoard = boards[0];
    final initialMs = firstBoard.timeLimitSec * 1000;

    _startTicker();

    return MatchTheFollowingViewState(
      sessionId: sessionId,
      boards: boards,
      currentBoardIndex: 0,
      boardStartedAt: now,
      remainingMs: initialMs,
      boardResolved: false,
      correctMatches: const {},
      mistakes: 0,
      boardSubmissions: const [],
      isCompleting: false,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _tick();
    });
  }

  void _tick() {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null || current.boardResolved || current.isCompleting || current.result != null) {
      return;
    }
    final board = current.currentBoard;
    if (board == null || current.boardStartedAt == null) return;

    final elapsed = DateTime.now().difference(current.boardStartedAt!).inMilliseconds;
    final totalLimitMs = board.timeLimitSec * 1000;
    final remaining = (totalLimitMs - elapsed).clamp(0, totalLimitMs);

    if (remaining <= 0) {
      handleTimeout();
    } else {
      state = AsyncValue.data(
        current.copyWith(remainingMs: remaining),
      );
    }
  }

  /// Called when user taps a left-column item.
  void selectLeft(String leftId) {
    final current = state.valueOrNull;
    if (current == null || current.isLocked) return;

    // If left item is already locked in a correct match, ignore
    if (current.correctMatches.containsKey(leftId)) return;

    // Toggle off if already selected
    if (current.selectedLeftId == leftId) {
      state = AsyncValue.data(
        current.copyWith(
          selectedLeftId: () => null,
          lastWrongAttemptLeftId: () => null,
          lastWrongAttemptRightId: () => null,
        ),
      );
      return;
    }

    ref.read(gameAudioServiceProvider).play(GameSound.answerSelect);

    state = AsyncValue.data(
      current.copyWith(
        selectedLeftId: () => leftId,
        lastWrongAttemptLeftId: () => null,
        lastWrongAttemptRightId: () => null,
      ),
    );
  }

  /// Called when user taps a right-column item.
  Future<void> selectRight(String rightId) async {
    final current = state.valueOrNull;
    if (current == null || current.isLocked) return;

    // If right item is already locked in a correct match, ignore
    if (current.correctMatches.containsValue(rightId)) return;

    // If no left item is selected, safely ignore (do NOT count as mistake)
    final leftId = current.selectedLeftId;
    if (leftId == null) return;

    final board = current.currentBoard;
    if (board == null) return;

    // Instant local evaluation using solutionMap
    final expectedRight = board.solutionMap[leftId];
    final isCorrect = expectedRight == rightId;

    if (isCorrect) {
      // 1. Correct Match
      final updatedMatches = Map<String, String>.from(current.correctMatches);
      updatedMatches[leftId] = rightId;

      ref.read(gameAudioServiceProvider).play(GameSound.matchConnect);

      final isBoardCleared = updatedMatches.length >= board.leftItems.length;

      if (isBoardCleared) {
        // Stop timer immediately for this board
        _ticker?.cancel();
        ref.read(gameAudioServiceProvider).play(GameSound.correct);

        final elapsedMs = DateTime.now()
            .difference(current.boardStartedAt ?? DateTime.now())
            .inMilliseconds
            .clamp(0, board.timeLimitSec * 1000);

        final submission = MatchBoardSubmission(
          questionCode: board.questionCode,
          matches: updatedMatches,
          mistakes: current.mistakes,
          timeTakenMs: elapsedMs,
          isTimeout: false,
        );

        final updatedSubmissions = [...current.boardSubmissions, submission];

        state = AsyncValue.data(
          current.copyWith(
            correctMatches: updatedMatches,
            selectedLeftId: () => null,
            boardResolved: true,
            remainingMs: 0,
            boardSubmissions: updatedSubmissions,
            lastWrongAttemptLeftId: () => null,
            lastWrongAttemptRightId: () => null,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 320));
        if (_disposed) return;

        await _advanceOrComplete();
      } else {
        // Correct pair locked, more pairs remaining on this board
        state = AsyncValue.data(
          current.copyWith(
            correctMatches: updatedMatches,
            selectedLeftId: () => null,
            lastWrongAttemptLeftId: () => null,
            lastWrongAttemptRightId: () => null,
          ),
        );
      }
    } else {
      // 2. Wrong Match Attempt
      ref.read(gameAudioServiceProvider).play(GameSound.wrong);

      state = AsyncValue.data(
        current.copyWith(
          mistakes: current.mistakes + 1,
          selectedLeftId: () => null,
          lastWrongAttemptLeftId: () => leftId,
          lastWrongAttemptRightId: () => rightId,
        ),
      );

      // Clear wrong attempt flash after brief moment
      await Future.delayed(const Duration(milliseconds: 400));
      if (_disposed) return;
      final latest = state.valueOrNull;
      if (latest != null && !latest.boardResolved) {
        state = AsyncValue.data(
          latest.copyWith(
            lastWrongAttemptLeftId: () => null,
            lastWrongAttemptRightId: () => null,
          ),
        );
      }
    }
  }

  /// Resolves the current board as a timeout and preserves partial correct matches.
  Future<void> handleTimeout() async {
    final current = state.valueOrNull;
    if (current == null || current.boardResolved || current.isCompleting || current.result != null) {
      return;
    }

    final board = current.currentBoard;
    if (board == null) return;

    _ticker?.cancel();
    ref.read(gameAudioServiceProvider).play(GameSound.wrong);

    final submission = MatchBoardSubmission(
      questionCode: board.questionCode,
      matches: Map<String, String>.from(current.correctMatches),
      mistakes: current.mistakes,
      timeTakenMs: board.timeLimitSec * 1000,
      isTimeout: true,
    );

    final updatedSubmissions = [...current.boardSubmissions, submission];

    state = AsyncValue.data(
      current.copyWith(
        boardResolved: true,
        remainingMs: 0,
        selectedLeftId: () => null,
        boardSubmissions: updatedSubmissions,
        lastWrongAttemptLeftId: () => null,
        lastWrongAttemptRightId: () => null,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 320));
    if (_disposed) return;

    await _advanceOrComplete();
  }

  Future<void> _advanceOrComplete() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final nextIndex = current.currentBoardIndex + 1;
    if (nextIndex < current.boards.length) {
      final nextBoard = current.boards[nextIndex];
      final now = DateTime.now();

      state = AsyncValue.data(
        current.copyWith(
          currentBoardIndex: nextIndex,
          boardStartedAt: now,
          remainingMs: nextBoard.timeLimitSec * 1000,
          boardResolved: false,
          correctMatches: const {},
          mistakes: 0,
          selectedLeftId: () => null,
          lastWrongAttemptLeftId: () => null,
          lastWrongAttemptRightId: () => null,
          isHintVisible: false,
        ),
      );

      _startTicker();
    } else {
      // All boards finished -> Single-flight batch completion
      await completeBatch();
    }
  }

  /// Sends the single batch completion request to /api/v1/quiz/match-the-following/complete.
  Future<void> completeBatch() async {
    final current = state.valueOrNull;
    if (current == null || current.isCompleting || current.result != null) return;

    _ticker?.cancel();

    state = AsyncValue.data(
      current.copyWith(
        isCompleting: true,
        completionError: () => null,
      ),
    );

    final ds = ref.read(quizDatasourceProvider);
    if (ds is! QuizRemoteDatasource) {
      state = AsyncValue.data(
        current.copyWith(
          isCompleting: false,
          completionError: () => "Cannot complete Match session: not a remote datasource.",
        ),
      );
      return;
    }

    try {
      final responseDto = await ds.completeMatchTheFollowing(
        session: current.sessionId,
        boards: current.boardSubmissions.map((s) => s.toDto()).toList(),
      );

      final domainResult = MatchTheFollowingResult.fromDto(responseDto);

      final isPerfect = domainResult.accuracyPercentage >= 100.0 &&
          domainResult.totalMistakes == 0;
      final didLevelUp = responseDto.level?.didLevelUp ?? false;

      ref.read(gameAudioServiceProvider).playQuizCompletion(
            isPerfect: isPerfect,
            leveledUp: didLevelUp,
          );

      // Reconcile wallet state if available
      try {
        ref.invalidate(walletControllerProvider);
      } catch (_) {}

      state = AsyncValue.data(
        current.copyWith(
          isCompleting: false,
          completionError: () => null,
          result: () => domainResult,
        ),
      );
    } catch (e, stack) {
      developer.log('Match the Following completion failed: $e', error: e, stackTrace: stack);
      if (_disposed) return;

      state = AsyncValue.data(
        current.copyWith(
          isCompleting: false,
          completionError: () =>
              "Couldn't submit your results. Check your connection and try again.",
        ),
      );
    }
  }

  /// Retries submitting the SAME batch of answers without re-creating a session.
  Future<void> retryCompletion() async {
    await completeBatch();
  }

  /// Toggles visibility of the board hint if available.
  void toggleHint() {
    final current = state.valueOrNull;
    if (current == null || current.isLocked) return;
    state = AsyncValue.data(
      current.copyWith(isHintVisible: !current.isHintVisible),
    );
  }

  /// Checks elapsed wall-clock time on application resume.
  void checkAppResumed() {
    final current = state.valueOrNull;
    if (current == null || current.boardResolved || current.isCompleting || current.result != null) {
      return;
    }
    final board = current.currentBoard;
    if (board == null || current.boardStartedAt == null) return;

    final elapsed = DateTime.now().difference(current.boardStartedAt!).inMilliseconds;
    if (elapsed >= board.timeLimitSec * 1000) {
      handleTimeout();
    }
  }

  /// Explicitly abandons the server-side session.
  Future<void> abandonSession() async {
    final current = state.valueOrNull;
    if (current == null || current.sessionId.isEmpty) return;
    _ticker?.cancel();
    final ds = ref.read(quizDatasourceProvider);
    if (ds is QuizRemoteDatasource) {
      try {
        await ds.abandonSession(current.sessionId);
      } catch (_) {}
    }
  }
}
