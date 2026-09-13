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
  final QuizDatasource _fallbackDatasource;

  String? _backendSessionId;
  String? _activeTopicId;

  QuizRemoteDatasource({
    required ApiClient apiClient,
    required QuizDatasource fallbackDatasource,
  })  : _apiClient = apiClient,
        _fallbackDatasource = fallbackDatasource;

  String? get activeSessionId => _backendSessionId;

  /// Creates a new server-side session in PostgreSQL.
  Future<String?> createSession({
    required String topicId,
    int questionCount = 10,
  }) async {
    _backendSessionId = null;
    _activeTopicId = null;
    final backendTopic = topicId.contains('accounting') ? 'accounting' : topicId;
    try {
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
        return _backendSessionId;
      }
    } catch (e) {
      developer.log(
        'Failed to create backend quiz session: $e',
        name: 'QuizRemote',
      );
    }
    return null;
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

    if (selectedOption != null) {
      try {
        if (_backendSessionId == null || _activeTopicId != question.topicId) {
          await createSession(topicId: question.topicId);
        }

        if (_backendSessionId != null) {
          final option = selectedOption == '__mcq_skipped__'
              ? 'skip'
              : selectedOption.toLowerCase();

          final body = {
            'session': _backendSessionId,
            'question': question.id,
            'option': option,
            'time_taken_ms': 3000,
          };

          final data = await _apiClient.post(
            '/quiz/answers/evaluate',
            body: body,
          );

          if (data is Map<String, dynamic>) {
            return AnswerEvaluation(
              isCorrect: data['is_correct'] as bool? ?? false,
              pointsEarned: data['points_earned'] as int? ?? 0,
            );
          }
        }
      } on AppException catch (e) {
        developer.log(
          'Backend evaluation failed (${e.message}), falling back to local.',
          name: 'QuizRemote',
        );
      } catch (e) {
        developer.log(
          'Unexpected evaluation error ($e), falling back to local.',
          name: 'QuizRemote',
        );
      }
    }

    return _fallbackDatasource.evaluateAnswer(question, answer);
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) async {
    final sessionId = _backendSessionId;
    _backendSessionId = null;
    _activeTopicId = null;

    if (sessionId != null) {
      try {
        final data = await _apiClient.post(
          '/quiz/sessions/complete',
          body: {'session': sessionId},
        );

        if (data is Map<String, dynamic>) {
          final finalScore = data['final_score'] as int? ?? 0;
          final correctCount = data['correct_count'] as int? ?? 0;
          final totalCount = data['total_questions'] as int? ?? session.questions.length;
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
            timeTaken: completedAt.difference(session.startedAt),
            createdAt: completedAt,
          );
        }
      } catch (e) {
        developer.log(
          'Failed to complete backend session ($e), falling back to local calculation.',
          name: 'QuizRemote',
        );
      }
    }

    return _fallbackDatasource.submitSession(session);
  }

  /// Request the two incorrect options to hide for 50:50 power-up.
  Future<List<String>?> applyFiftyFifty(String questionId) async {
    if (_backendSessionId == null) return null;

    try {
      final data = await _apiClient.post(
        '/quiz/power-ups/fifty-fifty',
        body: {
          'session': _backendSessionId,
          'question': questionId,
        },
      );

      if (data is Map<String, dynamic> && data['hidden_options'] is List) {
        return (data['hidden_options'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } catch (e) {
      developer.log('50:50 power-up backend call failed: $e', name: 'QuizRemote');
    }
    return null;
  }
}
