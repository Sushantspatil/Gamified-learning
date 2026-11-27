import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/answer_evaluation.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/entities/quiz_session.dart';

/// Implemented by `QuizRemoteDatasource` (the backend re-grades every game).
/// Tests use `QuizMockDatasource` from `test/mocks/`.
abstract class QuizDatasource {
  Future<AnswerEvaluation> evaluateAnswer(Question question, Answer answer);

  Future<QuizResult> submitSession(QuizSession session);
}
