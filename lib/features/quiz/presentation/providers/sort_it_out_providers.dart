import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_providers.dart';
import '../../../../core/audio/game_sound.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../questions/presentation/providers/question_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/remote/quiz_remote_datasource.dart';
import '../../domain/entities/sort_it_out_models.dart';
import 'quiz_providers.dart';

class SortItOutProvisionalFeedback {
  final bool isCorrect;
  final bool isTimeout;
  final String selectedOption;
  final String correctOption;
  final String? explanation;

  const SortItOutProvisionalFeedback({
    required this.isCorrect,
    required this.isTimeout,
    required this.selectedOption,
    required this.correctOption,
    this.explanation,
  });
}

class SortItOutViewState {
  final String? sessionId;
  final String pairType;
  final List<SortItOutCard> cards;
  final int currentIndex;
  final List<SortItOutAnswer> answers;
  final int currentCombo;
  final DateTime? currentCardStartedAt;
  final int timeRemainingMs;
  final int perQuestionTimeLimitSec;
  final bool cardResolved;
  final bool isCompleting;
  final String? completionError;
  final SortItOutResult? result;
  final SortItOutProvisionalFeedback? lastProvisionalFeedback;

  const SortItOutViewState({
    this.sessionId,
    this.pairType = 'credit_debit',
    this.cards = const [],
    this.currentIndex = 0,
    this.answers = const [],
    this.currentCombo = 0,
    this.currentCardStartedAt,
    this.timeRemainingMs = 7000,
    this.perQuestionTimeLimitSec = 7,
    this.cardResolved = false,
    this.isCompleting = false,
    this.completionError,
    this.result,
    this.lastProvisionalFeedback,
  });

  SortItOutCard? get currentCard =>
      currentIndex < cards.length ? cards[currentIndex] : null;

  SortItOutCard? get nextCard =>
      (currentIndex + 1) < cards.length ? cards[currentIndex + 1] : null;

  bool get isFinished => cards.isNotEmpty && currentIndex >= cards.length;

  double get timerProgress {
    final total = perQuestionTimeLimitSec * 1000;
    if (total <= 0) return 0;
    return (timeRemainingMs / total).clamp(0.0, 1.0);
  }

  SortItOutViewState copyWith({
    String? sessionId,
    String? pairType,
    List<SortItOutCard>? cards,
    int? currentIndex,
    List<SortItOutAnswer>? answers,
    int? currentCombo,
    DateTime? currentCardStartedAt,
    int? timeRemainingMs,
    int? perQuestionTimeLimitSec,
    bool? cardResolved,
    bool? isCompleting,
    String? completionError,
    bool clearCompletionError = false,
    SortItOutResult? result,
    SortItOutProvisionalFeedback? lastProvisionalFeedback,
    bool clearProvisionalFeedback = false,
  }) {
    return SortItOutViewState(
      sessionId: sessionId ?? this.sessionId,
      pairType: pairType ?? this.pairType,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      currentCombo: currentCombo ?? this.currentCombo,
      currentCardStartedAt: currentCardStartedAt ?? this.currentCardStartedAt,
      timeRemainingMs: timeRemainingMs ?? this.timeRemainingMs,
      perQuestionTimeLimitSec:
          perQuestionTimeLimitSec ?? this.perQuestionTimeLimitSec,
      cardResolved: cardResolved ?? this.cardResolved,
      isCompleting: isCompleting ?? this.isCompleting,
      completionError:
          clearCompletionError ? null : completionError ?? this.completionError,
      result: result ?? this.result,
      lastProvisionalFeedback: clearProvisionalFeedback
          ? null
          : lastProvisionalFeedback ?? this.lastProvisionalFeedback,
    );
  }
}

class SortItOutController
    extends AutoDisposeFamilyAsyncNotifier<SortItOutViewState, QuizSessionRequest> {
  Timer? _tickerTimer;
  bool _disposed = false;
  bool _isFinalizing = false;

  @override
  Future<SortItOutViewState> build(QuizSessionRequest request) async {
    _disposed = false;
    _isFinalizing = false;
    ref.onDispose(() {
      _disposed = true;
      _tickerTimer?.cancel();
    });

    final datasource = ref.read(quizDatasourceProvider);
    String? sessionId;
    String pairType = 'credit_debit';
    int timeLimitPerQuestion = 7;
    List<SortItOutCard> cards = const [];

    if (datasource is QuizRemoteDatasource) {
      if (datasource.activeSessionId != null &&
          datasource.activeSortItOutCards != null &&
          datasource.activeSortItOutCards!.isNotEmpty &&
          datasource.activeGameMode == 'sort_it_out' &&
          datasource.activeTopicId == request.topicId) {
        sessionId = datasource.activeSessionId;
        cards = datasource.activeSortItOutCards!;
        pairType = datasource.activePairType ?? 'credit_debit';
        timeLimitPerQuestion = datasource.activeTimeLimitPerQuestionSec ?? 7;
      } else {
        try {
          sessionId = await datasource.createSession(
            topicId: request.topicId,
            questionCount: 10,
            gameMode: 'sort_it_out',
          );
          if (datasource.activeSortItOutCards != null &&
              datasource.activeSortItOutCards!.isNotEmpty) {
            cards = datasource.activeSortItOutCards!;
          }
          if (datasource.activePairType != null &&
              datasource.activePairType!.isNotEmpty) {
            pairType = datasource.activePairType!;
          }
          if (datasource.activeTimeLimitPerQuestionSec != null &&
              datasource.activeTimeLimitPerQuestionSec! > 0) {
            timeLimitPerQuestion = datasource.activeTimeLimitPerQuestionSec!;
          }
        } catch (e) {
          developer.log(
            'Failed to create remote sort_it_out session: $e',
            name: 'SortItOutController',
          );
          rethrow;
        }
      }

      if (cards.isEmpty) {
        throw const ValidationException(
          'No Sort It Out cards available for the selected topic.',
          'no-sort-cards',
        );
      }
    } else {
      // Mock mode fallback only for test environments with QuizMockDatasource
      final questionsRequest = QuestionsForTopicAndTypeRequest(
        topicId: request.topicId,
        questionType: QuestionType.sortItRight,
      );
      final rawQuestions = await ref.refresh(
        questionsForTopicAndTypeProvider(questionsRequest).future,
      );

      final convertedCards = <SortItOutCard>[];
      for (final q in rawQuestions) {
        if (q is SortItRightQuestion) {
          for (var i = 0; i < q.itemsInOrder.length; i++) {
            convertedCards.add(
              SortItOutCard(
                id: '${q.id}-$i',
                prompt: q.itemsInOrder[i],
                points: q.points,
                options: [
                  QuestionOption(id: 'a', text: q.leftCategory),
                  QuestionOption(id: 'b', text: q.rightCategory),
                ],
                correctOption: i < q.correctSides.length
                    ? (q.correctSides[i] == SortSide.left ? 'a' : 'b')
                    : 'a',
                pairType: 'credit_debit',
                explanation: q.hint,
                timeLimitSec: 7,
              ),
            );
          }
        }
      }
      cards = convertedCards;
      sessionId ??=
          'mock-sort-session-${DateTime.now().millisecondsSinceEpoch}';
    }

    final initialLimit = cards.isNotEmpty
        ? (cards.first.timeLimitSec ?? timeLimitPerQuestion)
        : timeLimitPerQuestion;

    _startTicker();

    return SortItOutViewState(
      sessionId: sessionId,
      pairType: pairType,
      cards: cards,
      currentIndex: 0,
      answers: const [],
      currentCombo: 0,
      currentCardStartedAt: DateTime.now(),
      perQuestionTimeLimitSec: initialLimit,
      timeRemainingMs: initialLimit * 1000,
      cardResolved: false,
      isCompleting: false,
      completionError: null,
      result: null,
    );
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_disposed) return;
      _tick();
    });
  }

  void _tick() {
    final current = state.valueOrNull;
    if (current == null ||
        current.cards.isEmpty ||
        current.cardResolved ||
        current.isCompleting ||
        current.result != null ||
        current.currentCardStartedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now()
        .difference(current.currentCardStartedAt!)
        .inMilliseconds;
    final totalLimitMs = current.perQuestionTimeLimitSec * 1000;
    final remainingMs = totalLimitMs - elapsedMs;

    if (remainingMs <= 0) {
      handleTimeout();
    } else {
      state = AsyncValue.data(
        current.copyWith(timeRemainingMs: remainingMs),
      );
    }
  }

  /// Called when the active card's countdown timer expires.
  Future<void> handleTimeout() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.cardResolved ||
        current.isCompleting ||
        current.result != null) {
      return;
    }
    final card = current.currentCard;
    if (card == null) return;

    final elapsedMs = DateTime.now()
        .difference(current.currentCardStartedAt ?? DateTime.now())
        .inMilliseconds
        .clamp(0, 30000);

    final answer = SortItOutAnswer(
      question: card.id,
      option: 'timeout',
      timeTakenMs: elapsedMs,
      isTimeout: true,
    );

    final feedback = SortItOutProvisionalFeedback(
      isCorrect: false,
      isTimeout: true,
      selectedOption: 'timeout',
      correctOption: card.correctOption ?? 'a',
      explanation: card.explanation,
    );

    ref.read(gameAudioServiceProvider).play(GameSound.timeout);

    state = AsyncValue.data(
      current.copyWith(
        cardResolved: true,
        timeRemainingMs: 0,
        currentCombo: 0,
        answers: [...current.answers, answer],
        lastProvisionalFeedback: feedback,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 350));
    if (_disposed) return;

    await _advanceOrComplete();
  }

  /// Called when user swipes or taps a binary classification button ('a' or 'b').
  Future<void> submitOption(String option) async {
    final current = state.valueOrNull;
    if (current == null ||
        current.cardResolved ||
        current.isCompleting ||
        current.result != null) {
      return;
    }
    final card = current.currentCard;
    if (card == null) return;

    final normalizedOption = option.toLowerCase();
    final elapsedMs = DateTime.now()
        .difference(current.currentCardStartedAt ?? DateTime.now())
        .inMilliseconds
        .clamp(0, 30000);

    final isCorrect = card.correctOption != null &&
        card.correctOption!.toLowerCase() == normalizedOption;

    final answer = SortItOutAnswer(
      question: card.id,
      option: normalizedOption,
      timeTakenMs: elapsedMs,
      isTimeout: false,
    );

    final newCombo = isCorrect ? current.currentCombo + 1 : 0;
    if (isCorrect) {
      ref.read(gameAudioServiceProvider).play(GameSound.correct);
    } else {
      ref.read(gameAudioServiceProvider).play(GameSound.wrong);
    }

    final feedback = SortItOutProvisionalFeedback(
      isCorrect: isCorrect,
      isTimeout: false,
      selectedOption: normalizedOption,
      correctOption: card.correctOption ?? 'a',
      explanation: card.explanation,
    );

    state = AsyncValue.data(
      current.copyWith(
        cardResolved: true,
        currentCombo: newCombo,
        answers: [...current.answers, answer],
        lastProvisionalFeedback: feedback,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 280));
    if (_disposed) return;

    await _advanceOrComplete();
  }

  Future<void> _advanceOrComplete() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final nextIndex = current.currentIndex + 1;
    if (nextIndex < current.cards.length) {
      final nextCard = current.cards[nextIndex];
      final limitSec =
          nextCard.timeLimitSec ?? current.perQuestionTimeLimitSec;

      state = AsyncValue.data(
        current.copyWith(
          currentIndex: nextIndex,
          cardResolved: false,
          currentCardStartedAt: DateTime.now(),
          perQuestionTimeLimitSec: limitSec,
          timeRemainingMs: limitSec * 1000,
          clearProvisionalFeedback: true,
        ),
      );
    } else {
      // Reached end of deck — submit batch to server!
      await finalizeSession();
    }
  }

  /// Submits the completed card answer batch in a single authoritative call.
  Future<void> finalizeSession() async {
    final current = state.valueOrNull;
    if (current == null ||
        _isFinalizing ||
        current.isCompleting ||
        current.result != null) {
      return;
    }

    _isFinalizing = true;
    _tickerTimer?.cancel();

    state = AsyncValue.data(
      current.copyWith(
        isCompleting: true,
        clearCompletionError: true,
      ),
    );

    try {
      final datasource = ref.read(quizDatasourceProvider);
      SortItOutResult result;

      if (datasource is QuizRemoteDatasource &&
          current.sessionId != null &&
          current.sessionId!.isNotEmpty) {
        final submissionDtos =
            current.answers.map((a) => a.toDto()).toList(growable: false);

        final responseDto = await datasource.completeSortItOut(
          session: current.sessionId!,
          answers: submissionDtos,
        );

        result = SortItOutResult.fromDto(responseDto);

        ref.invalidate(profileControllerProvider);
        ref.invalidate(walletControllerProvider);
      } else {
        // Deterministic mock scoring mirroring authoritative backend rules
        var basePts = 0;
        var speedBonus = 0;
        var comboBonus = 0;
        var runningCombo = 0;
        var correctCount = 0;
        var timeoutCount = 0;
        var bestStreak = 0;

        final reviews = <SortItOutCardReview>[];

        for (var i = 0; i < current.cards.length; i++) {
          final card = current.cards[i];
          final answer = i < current.answers.length
              ? current.answers[i]
              : SortItOutAnswer(
                  question: card.id,
                  option: 'timeout',
                  timeTakenMs: 7000,
                  isTimeout: true,
                );

          final isTimeout = answer.isTimeout;
          final isCorrect = !isTimeout &&
              card.correctOption != null &&
              card.correctOption!.toLowerCase() == answer.option.toLowerCase();

          var cardBase = 0;
          var cardSpeed = 0;
          var cardCombo = 0;

          if (isTimeout) {
            timeoutCount++;
            runningCombo = 0;
          } else if (isCorrect) {
            correctCount++;
            runningCombo++;
            if (runningCombo > bestStreak) bestStreak = runningCombo;

            cardBase = 10;
            if (answer.timeTakenMs < 2000) {
              cardSpeed = 5;
            } else if (answer.timeTakenMs < 4000) {
              cardSpeed = 2;
            }

            cardCombo = ((runningCombo - 1) * 2).clamp(0, 10);
          } else {
            runningCombo = 0;
          }

          basePts += cardBase;
          speedBonus += cardSpeed;
          comboBonus += cardCombo;

          reviews.add(
            SortItOutCardReview(
              question: card.id,
              prompt: card.prompt,
              selectedOption: answer.option,
              correctOption: card.correctOption ?? 'a',
              isCorrect: isCorrect,
              isTimeout: isTimeout,
              timeTakenMs: answer.timeTakenMs,
              basePoints: cardBase,
              speedBonus: cardSpeed,
              comboBonus: cardCombo,
              pointsEarned: cardBase + cardSpeed + cardCombo,
              explanation: card.explanation,
            ),
          );
        }

        final finalScore = basePts + speedBonus + comboBonus;
        final accuracy = current.cards.isEmpty
            ? 0.0
            : (correctCount / current.cards.length) * 100.0;

        result = SortItOutResult(
          session: current.sessionId ?? 'mock-session',
          pairType: current.pairType,
          totalQuestions: current.cards.length,
          correctCount: correctCount,
          timeoutCount: timeoutCount,
          bestStreak: bestStreak,
          accuracyPercentage: accuracy,
          finalScore: finalScore,
          coinsAwarded: (finalScore / 10).round().clamp(5, 50),
          xpAwarded: (finalScore * 1.5).round().clamp(10, 150),
          gemsAwarded: accuracy >= 100.0 ? 2 : 0,
          scoreBreakdown: {
            'base_points': basePts,
            'speed_bonus': speedBonus,
            'combo_bonus': comboBonus,
            'final_score': finalScore,
          },
          cardsReview: reviews,
        );
      }

      ref.read(gameAudioServiceProvider).playQuizCompletion(
            isPerfect: result.accuracyPercentage >= 100.0,
            leveledUp: result.didLevelUp,
          );

      state = AsyncValue.data(
        current.copyWith(
          isCompleting: false,
          clearCompletionError: true,
          result: result,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(
          isCompleting: false,
          completionError:
              'Couldn\'t submit your results. Check your connection and retry.',
        ),
      );
    } finally {
      _isFinalizing = false;
    }
  }

  /// Retries batch completion after network connectivity restore.
  Future<void> retryCompletion() async {
    await finalizeSession();
  }

  /// Handles app lifecycle resynchronization after being backgrounded.
  void resyncAfterResume() {
    final current = state.valueOrNull;
    if (current == null ||
        current.cardResolved ||
        current.isCompleting ||
        current.result != null ||
        current.currentCardStartedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now()
        .difference(current.currentCardStartedAt!)
        .inMilliseconds;
    final totalLimitMs = current.perQuestionTimeLimitSec * 1000;

    if (elapsedMs >= totalLimitMs) {
      handleTimeout();
    } else {
      state = AsyncValue.data(
        current.copyWith(timeRemainingMs: totalLimitMs - elapsedMs),
      );
    }
  }

  /// Explicitly abandons this session if player exits mid-game.
  Future<void> abandonSession() async {
    final current = state.valueOrNull;
    final sessionId = current?.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final datasource = ref.read(quizDatasourceProvider);
    if (datasource is QuizRemoteDatasource) {
      await datasource.abandonSession(sessionId);
    }
  }
}

final sortItOutControllerProvider = AutoDisposeAsyncNotifierProvider.family<
    SortItOutController, SortItOutViewState, QuizSessionRequest>(
  SortItOutController.new,
);
