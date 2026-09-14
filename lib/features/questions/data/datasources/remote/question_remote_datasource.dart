import 'dart:developer' as developer;

import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import '../../../domain/entities/question.dart';
import '../../models/question_dto.dart';
import '../question_datasource.dart';

class QuestionRemoteDatasource implements QuestionDatasource {
  final ApiClient _apiClient;
  final QuestionDatasource? _fallbackDatasource;

  QuestionRemoteDatasource({
    required ApiClient apiClient,
    QuestionDatasource? fallbackDatasource,
  })  : _apiClient = apiClient,
        _fallbackDatasource = fallbackDatasource;

  @override
  Future<List<Question>> getQuestionsForTopic(String topicId) async {
    try {
      final mcqs = await getQuestionsForTopicAndType(topicId, QuestionType.mcq);
      final suddenDeaths = mcqs
          .map(
            (q) => SuddenDeathQuestion(
              id: 'sd-${q.id}',
              topicId: q.topicId,
              prompt: (q as McqQuestion).prompt,
              points: q.points,
              options: q.options,
              correctOptionId: q.correctOptionId,
            ),
          )
          .toList();
      if (_fallbackDatasource != null) {
        final fallbackQuestions =
            await _fallbackDatasource.getQuestionsForTopic(topicId);
        final nonMcqNonSudden = fallbackQuestions
            .where(
              (q) =>
                  q.type != QuestionType.mcq &&
                  q.type != QuestionType.suddenDeath,
            )
            .toList();
        return [...mcqs, ...suddenDeaths, ...nonMcqNonSudden];
      }
      return [...mcqs, ...suddenDeaths];
    } catch (_) {
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.getQuestionsForTopic(topicId);
      }
      rethrow;
    }
  }

  @override
  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  ) async {
    if (questionType != QuestionType.mcq &&
        questionType != QuestionType.suddenDeath &&
        _fallbackDatasource != null) {
      return _fallbackDatasource.getQuestionsForTopicAndType(
        topicId,
        questionType,
      );
    }

    final backendTopic = topicId.contains('accounting') ? 'accounting' : topicId;
    try {
      final responseData = await _apiClient.get(
        '/topics/$backendTopic/questions',
        queryParams: {'limit': '10'},
      );

      if (responseData is Map<String, dynamic>) {
        final dto = TopicQuestionsResponseDto.fromJson(responseData);
        if (dto.questions.isNotEmpty) {
          final mcqs = dto.questions.map((q) => q.toDomain(topicId)).toList();
          if (questionType == QuestionType.suddenDeath) {
            return mcqs
                .map(
                  (q) => SuddenDeathQuestion(
                    id: q.id,
                    topicId: q.topicId,
                    prompt: q.prompt,
                    points: q.points,
                    options: q.options,
                    correctOptionId: q.correctOptionId,
                  ),
                )
                .toList();
          }
          return mcqs;
        }
      }
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.getQuestionsForTopicAndType(topicId, questionType);
      }
      throw const NetworkException('No questions returned by the backend API.');
    } catch (e) {
      developer.log(
        'Backend error fetching questions: $e',
        name: 'QuestionRemote',
      );
      if (_fallbackDatasource != null) {
        return _fallbackDatasource.getQuestionsForTopicAndType(topicId, questionType);
      }
      rethrow;
    }
  }
}
