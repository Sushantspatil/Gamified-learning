import '../../../../questions/domain/entities/answer.dart';
import '../../../../questions/domain/entities/answer_evaluation.dart';
import '../../../../questions/domain/entities/question.dart';
import '../../../domain/entities/quiz_result.dart';
import '../../../domain/entities/quiz_session.dart';
import '../quiz_datasource.dart';

/// MOCK DATA — this is the ONLY place scoring math happens. Replace the
/// binding in quiz_providers.dart with a datasource that calls a Cloud
/// Function once scores must be server-authoritative; nothing above this
/// layer (controller, widgets) needs to change when that happens.
class QuizMockDatasource implements QuizDatasource {
  @override
  Future<AnswerEvaluation> evaluateAnswer(Question question, Answer answer) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return switch ((question, answer)) {
      (McqQuestion q, McqAnswer a) => _evaluateOptionBased(q.correctOptionId, a.selectedOptionId, q.points),
      (SuddenDeathQuestion q, SuddenDeathAnswer a) =>
        _evaluateOptionBased(q.correctOptionId, a.selectedOptionId, q.points),
      (MatchTheFollowingQuestion q, MatchTheFollowingAnswer a) => _evaluateMatch(q, a),
      (SortItRightQuestion q, SortAnswer a) => _evaluateSort(q, a),
      _ => const AnswerEvaluation(isCorrect: false, pointsEarned: 0),
    };
  }

  AnswerEvaluation _evaluateOptionBased(String correctOptionId, String selectedOptionId, int points) {
    final isCorrect = correctOptionId == selectedOptionId;
    return AnswerEvaluation(isCorrect: isCorrect, pointsEarned: isCorrect ? points : 0);
  }

  AnswerEvaluation _evaluateMatch(MatchTheFollowingQuestion question, MatchTheFollowingAnswer answer) {
    var correctPairs = 0;
    for (final pair in question.pairs) {
      if (answer.matchedPairIds[pair.id] == pair.id) correctPairs++;
    }
    final isFullyCorrect = question.pairs.isNotEmpty && correctPairs == question.pairs.length;
    final pointsEarned =
        question.pairs.isEmpty ? 0 : (question.points * correctPairs / question.pairs.length).round();
    return AnswerEvaluation(isCorrect: isFullyCorrect, pointsEarned: pointsEarned);
  }

  AnswerEvaluation _evaluateSort(SortItRightQuestion question, SortAnswer answer) {
    final isCorrect = _listEquals(question.itemsInOrder, answer.orderedItems);
    return AnswerEvaluation(isCorrect: isCorrect, pointsEarned: isCorrect ? question.points : 0);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) async {
    await Future.delayed(const Duration(milliseconds: 400));

    var earned = 0;
    var max = 0;
    var correct = 0;
    for (final record in session.answeredRecords) {
      earned += record.evaluation.pointsEarned;
      max += record.question.points;
      if (record.evaluation.isCorrect) correct++;
    }
    for (final question in session.questions.skip(session.answeredRecords.length)) {
      max += question.points;
    }

    return QuizResult(
      sessionId: session.id,
      topicId: session.topicId,
      score: Score(
        earnedPoints: earned,
        maxPoints: max,
        correctCount: correct,
        totalCount: session.questions.length,
      ),
      records: session.answeredRecords,
      endedEarly: session.endedEarly,
    );
  }
}
