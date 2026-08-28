import '../../domain/entities/question.dart';
import '../../domain/repositories/question_repository.dart';
import '../datasources/question_datasource.dart';

class QuestionRepositoryImpl implements QuestionRepository {
  final QuestionDatasource _datasource;

  QuestionRepositoryImpl(this._datasource);

  @override
  Future<List<Question>> getQuestionsForTopic(String topicId) {
    return _datasource.getQuestionsForTopic(topicId);
  }

  @override
  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  ) {
    return _datasource.getQuestionsForTopicAndType(topicId, questionType);
  }
}
