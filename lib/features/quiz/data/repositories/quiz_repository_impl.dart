import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/answer_evaluation.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/entities/quiz_session.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../datasources/quiz_datasource.dart';

class QuizRepositoryImpl implements QuizRepository {
  final QuizDatasource _datasource;

  QuizRepositoryImpl(this._datasource);

  @override
  Future<AnswerEvaluation> evaluateAnswer(Question question, Answer answer) {
    return _datasource.evaluateAnswer(question, answer);
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) {
    return _datasource.submitSession(session);
  }
}
