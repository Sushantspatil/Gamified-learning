import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_endpoints.dart';
import '../../../../../core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/entities/quiz_session.dart';
import '../quiz_datasource.dart';

class QuizRemoteDatasource implements QuizDatasource {
  final ApiClient _apiClient;

  String? _backendSessionId;
  String? _activeTopicId;
  List<Question>? _activeSessionQuestions;
  DateTime? _questionStartTime;

  QuizRemoteDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  String? get activeSessionId => _backendSessionId;
  List<Question>? get activeSessionQuestions => _activeSessionQuestions;

  /// Creates a new server-side session in PostgreSQL.
  Future<String> createSession({
    required String topicId,
    int questionCount = 10,
    List<String>? questionCodes,
  }) async {
    _backendSessionId = null;
    _activeTopicId = null;
    _activeSessionQuestions = null;
    final backendTopic = topicId.contains('accounting')
        ? 'accounting'
        : topicId;
    final requestDto = CreateSessionRequestDto(
      topic: backendTopic,
      questionCount: questionCount,
      abandonStale: true,
      questionCodes: questionCodes,
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
        _questionStartTime = DateTime.now();

        if (sessionDto.questions.isNotEmpty) {
          _activeSessionQuestions = sessionDto.questions
              .map((q) => QuestionDto.fromJson(q).toDomain(topicId))
              .toList();
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

    final data = await _apiClient.post(
      ApiEndpoints.quizCompleteSession,
      body: CompleteSessionRequestDto(session: sessionId).toJson(),
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
