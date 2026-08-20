import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/answer_evaluation.dart';
import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/entities/quiz_session.dart';

/// Implemented today by [QuizMockDatasource], which scores client-side.
/// Swap for a datasource that posts to a Cloud Function once the backend
/// must become authoritative over scores (Step 10).
abstract class QuizDatasource {
  Future<AnswerEvaluation> evaluateAnswer(Question question, Answer answer);

  Future<QuizResult> submitSession(QuizSession session);
}
