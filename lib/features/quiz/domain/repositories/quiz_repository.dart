import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/answer_evaluation.dart';
import '../../../questions/domain/entities/question.dart';
import '../entities/quiz_result.dart';
import '../entities/quiz_session.dart';

/// Scoring lives entirely behind this interface — never in widgets or
/// controllers — so it can move from local mock evaluation to an
/// authoritative server call (Cloud Function) later without touching
/// presentation code.
abstract class QuizRepository {
  Future<AnswerEvaluation> evaluateAnswer(Question question, Answer answer);

  Future<QuizResult> submitSession(QuizSession session);
}
