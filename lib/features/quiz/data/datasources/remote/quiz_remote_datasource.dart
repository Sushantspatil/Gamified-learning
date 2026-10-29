import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_endpoints.dart';
import 'package:skillverse_app/core/network/backend_topic_mapper.dart';
import '../../../../../core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/entities/quiz_session.dart';
import '../../../domain/entities/sort_it_out_models.dart';
import '../../../domain/entities/match_the_following_models.dart';
import '../quiz_datasource.dart';

/// Backend `MCQCorrectAnswerPoints` (docs/points_calculation.md).
const int mcqCorrectAnswerPoints = 10;

class QuizRemoteDatasource implements QuizDatasource {
  final ApiClient _apiClient;

  /// MCQ answers graded locally; sent with [submitSession] in one request.
  final List<SessionAnswerDto> _pendingAnswers = [];

  String? _backendSessionId;
  String? _activeTopicId;
  String? _activeGameMode;
  List<Question>? _activeSessionQuestions;
  List<SortItOutCard>? _activeSortItOutCards;
  List<MatchBoard>? _activeMatchBoards;
  String? _activePairType;
  int? _activeTimeLimitPerQuestionSec;
  DateTime? _questionStartTime;

  QuizRemoteDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  String? get activeSessionId => _backendSessionId;
  String? get activeTopicId => _activeTopicId;
  String? get activeGameMode => _activeGameMode;
  List<Question>? get activeSessionQuestions => _activeSessionQuestions;
  List<SortItOutCard>? get activeSortItOutCards => _activeSortItOutCards;
  List<MatchBoard>? get activeMatchBoards => _activeMatchBoards;
  String? get activePairType => _activePairType;
  int? get activeTimeLimitPerQuestionSec => _activeTimeLimitPerQuestionSec;

  void clearActiveSession() {
    _pendingAnswers.clear();
    _backendSessionId = null;
    _activeTopicId = null;
    _activeGameMode = null;
    _activeSessionQuestions = null;
    _activeSortItOutCards = null;
    _activeMatchBoards = null;
    _activePairType = null;
    _activeTimeLimitPerQuestionSec = null;
    _questionStartTime = null;
  }

  /// Creates a new server-side session in PostgreSQL.
  Future<String> createSession({
    required String topicId,
    int questionCount = 10,
    List<String>? questionCodes,
    String? gameMode,
    int? chapterNo,
    String? pairType,
    int? timeLimitPerQuestionSec,
  }) async {
    _pendingAnswers.clear();
    _backendSessionId = null;
    _activeTopicId = null;
    _activeGameMode = null;
    _activeSessionQuestions = null;
    _activeSortItOutCards = null;
    _activeMatchBoards = null;
    _activePairType = null;
    _activeTimeLimitPerQuestionSec = null;
    final backendTopic = mapToBackendTopicId(topicId);
    final selectedGameMode = gameMode ?? 'mcq';
    final requestDto = CreateSessionRequestDto(
      topic: backendTopic,
      questionCount: questionCount,
      abandonStale: true,
      questionCodes: questionCodes,
      gameMode: selectedGameMode,
      chapterNo: chapterNo,
      pairType: pairType,
      timeLimitPerQuestionSec: timeLimitPerQuestionSec,
    );
    final response = await _apiClient.post(
      ApiEndpoints.quizCreateSession,
      body: requestDto.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final sessionDto = SessionCreatedResponseDto.fromJson(response);
      if (sessionDto.session.isNotEmpty) {
        _backendSessionId = sessionDto.session;
        _activeTopicId = topicId;
        _activeGameMode = sessionDto.gameMode.isNotEmpty
            ? sessionDto.gameMode
            : selectedGameMode;
        _activePairType = sessionDto.pairType;
        _activeTimeLimitPerQuestionSec = sessionDto.timeLimitPerQuestionSec;
        _questionStartTime = DateTime.now();

        if (sessionDto.questions.isNotEmpty) {
          _activeSessionQuestions = sessionDto.questions
              .map((q) => QuestionDto.fromJson(q).toDomain(topicId))
              .toList();

          _activeSortItOutCards = sessionDto.questions.map((q) {
            final dto = QuestionDto.fromJson(q);
            return SortItOutCard(
              id: dto.question,
              prompt: dto.prompt,
              points: dto.points,
              hint: dto.hint,
              timeLimitSec:
                  dto.timeLimitSec ?? sessionDto.timeLimitPerQuestionSec,
              options: dto.options.map((o) => o.toDomain()).toList(),
              correctOption: dto.correctOption,
              pairType: dto.pairType ?? sessionDto.pairType,
              explanation: dto.explanation,
            );
          }).toList();
        }

        if (sessionDto.boards != null && sessionDto.boards!.isNotEmpty) {
          _activeMatchBoards = sessionDto.boards!.map((b) {
            return MatchBoard(
              questionCode: b.questionCode,
              prompt: b.prompt,
              timeLimitSec: b.timeLimitSec,
              leftItems: b.leftItems
                  .map((i) => MatchPairItem(id: i.id, text: i.text))
                  .toList(),
              rightItems: b.rightItems
                  .map((i) => MatchPairItem(id: i.id, text: i.text))
                  .toList(),
              solutionMap: b.solutionMap,
              hint: b.hint,
              explanation: b.explanation,
            );
          }).toList();
        }

        return _backendSessionId!;
      }
    }

    throw const ServerException(
      'Invalid response while creating the quiz session.',
      'invalid-quiz-session',
    );
  }

  @override
  Future<AnswerEvaluation> evaluateAnswer(
    Question question,
    Answer answer,
  ) async {
    final String? selectedOption = answer is McqAnswer
        ? answer.selectedOptionId
        : answer is SuddenDeathAnswer
        ? answer.selectedOptionId
        : null;

    if (selectedOption == null || question is! McqQuestion) {
      throw const ValidationException(
        'This quiz mode is not supported by the backend yet.',
        'unsupported-quiz-mode',
      );
    }

    if (_backendSessionId == null || _activeTopicId != question.topicId) {
      await createSession(topicId: question.topicId);
    }

    final option = selectedOption == '__mcq_skipped__'
        ? 'skip'
        : selectedOption.toLowerCase();

    // Look up selected option text for robust multi-layered backend verification
    String? selectedText;
    if (option != 'skip') {
      for (final opt in question.options) {
        if (opt.id.toLowerCase() == option) {
          selectedText = opt.text;
          break;
        }
      }
    }

    final now = DateTime.now();
    var timeTakenMs = 3000;
    if (_questionStartTime != null) {
      timeTakenMs = now.difference(_questionStartTime!).inMilliseconds;
      if (timeTakenMs < 500) timeTakenMs = 500;
      if (timeTakenMs > 15000) timeTakenMs = 15000;
    }
    _questionStartTime = now;

    // The session already carries the correct option, so grade on the device with
    // zero network wait; the backend re-grades every answer on complete.
    if (question.correctOptionId.isNotEmpty) {
      _pendingAnswers.add(
        SessionAnswerDto(
          question: question.id,
          option: option,
          selectedText: selectedText,
          timeTakenMs: timeTakenMs,
        ),
      );
      final isCorrect =
          option != 'skip' && option == question.correctOptionId.toLowerCase();
      return AnswerEvaluation(
        isCorrect: isCorrect,
        pointsEarned: isCorrect ? mcqCorrectAnswerPoints : 0,
      );
    }

    final requestDto = EvaluateAnswerRequestDto(
      session: _backendSessionId!,
      question: question.id,
      option: option,
      selectedText: selectedText,
      timeTakenMs: timeTakenMs,
    );
    final data = await _apiClient.post(
      ApiEndpoints.quizEvaluateAnswer,
      body: requestDto.toJson(),
    );

    if (data is Map<String, dynamic>) {
      final resDto = AnswerResultResponseDto.fromJson(data);
      return AnswerEvaluation(
        isCorrect: resDto.isCorrect,
        pointsEarned: resDto.pointsEarned,
      );
    }

    throw const ServerException(
      'Invalid response while evaluating the answer.',
      'invalid-answer-evaluation',
    );
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) async {
    final sessionId =
        (_backendSessionId != null && _backendSessionId!.isNotEmpty)
        ? _backendSessionId!
        : session.id;
    _backendSessionId = null;
    _activeTopicId = null;
    _questionStartTime = null;

    if (sessionId.isEmpty || session.quizType != QuestionType.mcq) {
      throw const ValidationException(
        'This quiz mode is not supported by the backend yet.',
        'unsupported-quiz-mode',
      );
    }

    final answers = List<SessionAnswerDto>.of(_pendingAnswers);
    _pendingAnswers.clear();
    final data = await _apiClient.post(
      ApiEndpoints.quizCompleteSession,
      body: CompleteSessionRequestDto(
        session: sessionId,
        answers: answers,
      ).toJson(),
    );

    if (data is Map<String, dynamic>) {
      final resDto = SessionCompleteResponseDto.fromJson(data);

      var recordedPoints = 0;
      var computedCorrectCount = 0;
      for (final record in session.answeredRecords) {
        if (record.evaluation.isCorrect) {
          recordedPoints += record.evaluation.pointsEarned;
          computedCorrectCount++;
        }
      }

      final earnedPoints = resDto.finalScore ?? recordedPoints;
      final maxScore = resDto.maxScore ?? 0;
      final correctCount = resDto.correctCount ?? computedCorrectCount;
      final totalCount = resDto.totalQuestions ?? session.questions.length;
      final completedAt = session.completedAt;

      final xpBreakdown = resDto.xpBreakdown.containsKey('speed_bonus_xp')
          ? const <RewardBreakdownItem>[]
          : _parseBreakdown(
              resDto.xpBreakdown,
              expectedTotal: resDto.xpAwarded,
            );
      final coinBreakdown =
          resDto.coinBreakdown.containsKey('accuracy_bonus_coins')
          ? const <RewardBreakdownItem>[]
          : _parseBreakdown(
              resDto.coinBreakdown,
              expectedTotal: resDto.coinsAwarded,
            );
      final levelUpReward = resDto.levelUpReward;

      return QuizResult(
        sessionId: sessionId,
        userId: session.userId,
        subjectId: session.subjectId,
        chapterId: session.chapterId,
        topicId: session.topicId,
        quizType: session.quizType,
        score: Score(
          earnedPoints: earnedPoints,
          maxPoints: maxScore,
          correctCount: correctCount,
          totalCount: totalCount,
        ),
        records: session.answeredRecords,
        endedEarly: session.endedEarly,
        streakCount: resDto.streak?.currentStreak ?? 0,
        xpAwarded: resDto.xpAwarded,
        coinsAwarded: resDto.coinsAwarded,
        gemsAwarded: resDto.gemsAwarded,
        didLevelUp: resDto.level?.didLevelUp ?? false,
        rewardBreakdown: QuizRewardBreakdown(
          score: _parseBreakdown(
            resDto.scoreBreakdown,
            expectedTotal: earnedPoints,
          ),
          xp: xpBreakdown,
          coins: coinBreakdown,
          levelUp: levelUpReward == null
              ? const []
              : [
                  RewardBreakdownItem(
                    key: 'level_up_bonus_xp',
                    amount: levelUpReward.xp,
                  ),
                  RewardBreakdownItem(
                    key: 'level_up_bonus_coins',
                    amount: levelUpReward.coins,
                  ),
                  RewardBreakdownItem(
                    key: 'level_up_bonus_gems',
                    amount: levelUpReward.gems,
                  ),
                ],
        ),
        levelProgress: resDto.level != null
            ? QuizLevelProgress(
                currentLevel: resDto.level!.current,
                experience: resDto.level!.experience,
                nextLevelExperience: resDto.level!.nextLevelExp,
              )
            : null,
        timeTaken: completedAt.difference(session.startedAt),
        createdAt: completedAt,
      );
    }

    throw const ServerException(
      'Invalid response while completing the quiz session.',
      'invalid-quiz-result',
    );
  }

  /// Request the two incorrect options to hide for 50:50 power-up.
  Future<List<String>?> applyFiftyFifty(String questionId) async {
    if (_backendSessionId == null) return null;

    try {
      final data = await _apiClient.post(
        ApiEndpoints.quizFiftyFifty,
        body: FiftyFiftyRequestDto(
          session: _backendSessionId!,
          question: questionId,
        ).toJson(),
      );

      if (data is Map<String, dynamic>) {
        final resDto = FiftyFiftyResponseDto.fromJson(data);
        if (resDto.hiddenOptions.isNotEmpty) {
          return resDto.hiddenOptions;
        }
      }
    } catch (e) {
      developer.log(
        '50:50 power-up backend call failed: $e',
        name: 'QuizRemote',
      );
    }
    return null;
  }

  /// Completes a Sort It Out session authoritatively via batch submission.
  Future<CompleteSortItOutResponseDto> completeSortItOut({
    required String session,
    required List<SortItOutAnswerSubmissionDto> answers,
  }) async {
    final body = CompleteSortItOutRequestDto(
      session: session,
      answers: answers,
    ).toJson();

    final data = await _apiClient.post(
      ApiEndpoints.quizSortItOutComplete,
      body: body,
    );

    if (data is Map<String, dynamic>) {
      _backendSessionId = null;
      _activeSortItOutCards = null;
      _activeGameMode = null;
      _activeTopicId = null;
      return CompleteSortItOutResponseDto.fromJson(data);
    }

    throw const ServerException(
      'Invalid response while completing Sort It Out session.',
      'invalid-sort-it-out-result',
    );
  }

  /// Completes a Match the Following session with batch board submissions.
  Future<CompleteMatchTheFollowingResponseDto> completeMatchTheFollowing({
    required String session,
    required List<MatchBoardAnswerSubmissionDto> boards,
  }) async {
    final body = CompleteMatchTheFollowingRequestDto(
      session: session,
      boards: boards,
    ).toJson();

    final data = await _apiClient.post(
      ApiEndpoints.quizMatchTheFollowingComplete,
      body: body,
    );

    if (data is Map<String, dynamic>) {
      _backendSessionId = null;
      _activeMatchBoards = null;
      _activeGameMode = null;
      _activeTopicId = null;
      return CompleteMatchTheFollowingResponseDto.fromJson(data);
    }

    throw const ServerException(
      'Invalid response while completing Match the Following session.',
      'invalid-match-the-following-result',
    );
  }

  /// Explicitly abandons an in-progress session.
  Future<void> abandonSession([String? sessionId]) async {
    final id = sessionId ?? _backendSessionId;
    _backendSessionId = null;
    _activeMatchBoards = null;
    _activeSortItOutCards = null;
    _activeGameMode = null;
    _activeTopicId = null;
    if (id == null || id.isEmpty) return;
    try {
      await _apiClient.post(
        ApiEndpoints.quizAbandonSession,
        body: {'session': id},
      );
    } catch (e) {
      developer.log('Abandon session failed: $e', name: 'QuizRemote');
    }
  }

  List<RewardBreakdownItem> _parseBreakdown(
    Map<String, int> values, {
    int? expectedTotal,
  }) {
    if (values.isEmpty) return const [];
    if (expectedTotal != null &&
        values.values.fold<int>(0, (sum, value) => sum + value) !=
            expectedTotal) {
      return const [];
    }
    return values.entries
        .map(
          (entry) => RewardBreakdownItem(key: entry.key, amount: entry.value),
        )
        .toList(growable: false);
  }
}
