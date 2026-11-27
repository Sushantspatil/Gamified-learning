import '../../domain/entities/question.dart';

/// Implemented by `QuestionRemoteDatasource` (the backend). Tests use a mock
/// from `test/mocks/`.
abstract class QuestionDatasource {
  Future<List<Question>> getQuestionsForTopic(String topicId);

  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  );
}
