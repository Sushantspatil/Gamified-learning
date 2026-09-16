import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import '../../../domain/entities/question.dart';
import '../../models/question_dto.dart';
import '../question_datasource.dart';

class QuestionRemoteDatasource implements QuestionDatasource {
  final ApiClient _apiClient;

  QuestionRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<Question>> getQuestionsForTopic(String topicId) async {
    return getQuestionsForTopicAndType(topicId, QuestionType.mcq);
  }

  @override
  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  ) async {
    if (questionType != QuestionType.mcq) {
      return const [];
    }

    final backendTopic = topicId.contains('accounting')
        ? 'accounting'
        : topicId;
    final responseData = await _apiClient.get(
      '/topics/$backendTopic/questions',
      queryParams: {'limit': '10'},
    );

    if (responseData is Map<String, dynamic>) {
      final dto = TopicQuestionsResponseDto.fromJson(responseData);
      if (dto.questions.isNotEmpty) {
        return dto.questions.map((q) => q.toDomain(topicId)).toList();
      }
    }

    throw const NetworkException('No questions returned by the backend API.');
  }
}
