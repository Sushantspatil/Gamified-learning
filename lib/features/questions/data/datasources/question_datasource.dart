import '../../domain/entities/question.dart';

/// Implemented today by [QuestionMockDatasource]. Swap for a Firestore-backed
/// implementation (questions collection) later.
abstract class QuestionDatasource {
  Future<List<Question>> getQuestionsForTopic(String topicId);

  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  );
}
