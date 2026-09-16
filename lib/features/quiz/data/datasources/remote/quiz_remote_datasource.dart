import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/entities/quiz_session.dart';
import '../quiz_datasource.dart';

class QuizRemoteDatasource implements QuizDatasource {
  final ApiClient _apiClient;

  String? _backendSessionId;
  String? _activeTopicId;

  QuizRemoteDatasource({required ApiClient apiClient}) : _apiClient = apiClient;

  String? get activeSessionId => _backendSessionId;

  /// Creates a new server-side session in PostgreSQL.
  Future<String> createSession({
    required String topicId,
    int questionCount = 10,
  }) async {
    _backendSessionId = null;
    _activeTopicId = null;
    final backendTopic = topicId.contains('accounting')
        ? 'accounting'
        : topicId;
    final response = await _apiClient.post(
      '/quiz/sessions/create',
      body: {
        'topic': backendTopic,
        'question_count': questionCount,
        'abandon_stale': true,
      },
    );

    if (response is Map<String, dynamic> && response['session'] is String) {
      _backendSessionId = response['session'] as String;
      _activeTopicId = topicId;
      return _backendSessionId!;
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

    final data = await _apiClient.post(
      '/quiz/answers/evaluate',
      body: {
        'session': _backendSessionId,
        'question': question.id,
        'option': option,
        'time_taken_ms': 3000,
      },
    );

    if (data is Map<String, dynamic>) {
      return AnswerEvaluation(
        isCorrect: data['is_correct'] as bool? ?? false,
        pointsEarned: data['points_earned'] as int? ?? 0,
      );
    }

    throw const ServerException(
      'Invalid response while evaluating the answer.',
      'invalid-answer-evaluation',
    );
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) async {
    final sessionId = _backendSessionId;
    _backendSessionId = null;
    _activeTopicId = null;

    if (sessionId == null || session.quizType != QuestionType.mcq) {
      throw const ValidationException(
        'This quiz mode is not supported by the backend yet.',
        'unsupported-quiz-mode',
      );
    }

    final data = await _apiClient.post(
      '/quiz/sessions/complete',
      body: {'session': sessionId},
    );

    if (data is Map<String, dynamic>) {
      final finalScore = data['final_score'] as int? ?? 0;
      final correctCount = data['correct_count'] as int? ?? 0;
      final totalCount =
          data['total_questions'] as int? ?? session.questions.length;
      final completedAt = session.completedAt;

      return QuizResult(
        sessionId: sessionId,
        userId: session.userId,
        subjectId: session.subjectId,
        chapterId: session.chapterId,
        topicId: session.topicId,
        quizType: session.quizType,
        score: Score(
          earnedPoints: finalScore,
          maxPoints: session.questions.fold(0, (sum, q) => sum + q.points),
          correctCount: correctCount,
          totalCount: totalCount,
        ),
        records: session.answeredRecords,
        endedEarly: session.endedEarly,
        streakCount: data['streak'] is Map<String, dynamic>
            ? (data['streak']['current_streak'] as int? ?? 0)
            : 0,
        xpAwarded: data['xp_awarded'] as int? ?? 0,
        coinsAwarded: data['coins_awarded'] as int? ?? 0,
        gemsAwarded: data['gems_awarded'] as int? ?? 0,
        didLevelUp: data['level'] is Map<String, dynamic>
            ? (data['level']['did_level_up'] as bool? ?? false)
            : false,
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
        '/quiz/power-ups/fifty-fifty',
        body: {'session': _backendSessionId, 'question': questionId},
      );

      if (data is Map<String, dynamic> && data['hidden_options'] is List) {
        return (data['hidden_options'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } catch (e) {
      developer.log(
        '50:50 power-up backend call failed: $e',
        name: 'QuizRemote',
      );
    }
    return null;
  }
}
