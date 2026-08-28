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
  Future<AnswerEvaluation> evaluateAnswer(
    Question question,
    Answer answer,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    return switch ((question, answer)) {
      (McqQuestion q, McqAnswer a) => _evaluateOptionBased(
        q.correctOptionId,
        a.selectedOptionId,
        q.points,
      ),
      (SuddenDeathQuestion q, SuddenDeathAnswer a) => _evaluateOptionBased(
        q.correctOptionId,
        a.selectedOptionId,
        q.points,
      ),
      (MatchTheFollowingQuestion q, MatchTheFollowingAnswer a) =>
        _evaluateMatch(q, a),
      (SortItRightQuestion q, SortAnswer a) => _evaluateSort(q, a),
      _ => const AnswerEvaluation(isCorrect: false, pointsEarned: 0),
    };
  }

  AnswerEvaluation _evaluateOptionBased(
    String correctOptionId,
    String selectedOptionId,
    int points,
  ) {
    final isCorrect = correctOptionId == selectedOptionId;
    return AnswerEvaluation(
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? points : 0,
    );
  }

  AnswerEvaluation _evaluateMatch(
    MatchTheFollowingQuestion question,
    MatchTheFollowingAnswer answer,
  ) {
    var correctPairs = 0;
    for (final pair in question.pairs) {
      if (answer.matchedPairIds[pair.id] == pair.id) correctPairs++;
    }
    final isFullyCorrect =
        question.pairs.isNotEmpty && correctPairs == question.pairs.length;
    final pointsEarned = question.pairs.isEmpty
        ? 0
        : (question.points * correctPairs / question.pairs.length).round();
    return AnswerEvaluation(
      isCorrect: isFullyCorrect,
      pointsEarned: pointsEarned,
    );
  }

  AnswerEvaluation _evaluateSort(
    SortItRightQuestion question,
    SortAnswer answer,
  ) {
    var correctPositions = 0;
    final comparableLength =
        question.itemsInOrder.length < answer.orderedItems.length
        ? question.itemsInOrder.length
        : answer.orderedItems.length;
    for (var i = 0; i < comparableLength; i++) {
      if (question.itemsInOrder[i] == answer.orderedItems[i]) {
        correctPositions++;
      }
    }
    final isFullyCorrect =
        question.itemsInOrder.isNotEmpty &&
        correctPositions == question.itemsInOrder.length;
    final pointsEarned = question.itemsInOrder.isEmpty
        ? 0
        : (question.points * correctPositions / question.itemsInOrder.length)
              .round();
    return AnswerEvaluation(
      isCorrect: isFullyCorrect,
      pointsEarned: pointsEarned,
    );
  }

  @override
  Future<QuizResult> submitSession(QuizSession session) async {
    await Future.delayed(const Duration(milliseconds: 400));

    var earned = 0;
    var max = 0;
    for (final record in session.answeredRecords) {
      earned += record.evaluation.pointsEarned;
      max += record.question.points;
    }
    for (final question in session.questions.skip(
      session.answeredRecords.length,
    )) {
      max += question.points;
    }

    final metric = _metricForSession(session);
    final streakCount = session.quizType == QuestionType.suddenDeath
        ? metric.correct
        : 0;
    final completedAt = session.completedAt;

    return QuizResult(
      sessionId: session.id,
      userId: session.userId,
      subjectId: session.subjectId,
      chapterId: session.chapterId,
      topicId: session.topicId,
      quizType: session.quizType,
      score: Score(
        earnedPoints: earned,
        maxPoints: max,
        correctCount: metric.correct,
        totalCount: metric.total,
      ),
      records: session.answeredRecords,
      endedEarly: session.endedEarly,
      streakCount: streakCount,
      timeTaken: completedAt.difference(session.startedAt),
      createdAt: completedAt,
    );
  }

  ({int correct, int total}) _metricForSession(QuizSession session) {
    return switch (session.quizType) {
      QuestionType.mcq => _questionMetric(session),
      QuestionType.suddenDeath => _questionMetric(session),
      QuestionType.matchTheFollowing => _matchMetric(session),
      QuestionType.sortItRight => _sortMetric(session),
    };
  }

  ({int correct, int total}) _questionMetric(QuizSession session) {
    var correct = 0;
    for (final record in session.answeredRecords) {
      if (record.evaluation.isCorrect) correct++;
    }
    return (correct: correct, total: session.questions.length);
  }

  ({int correct, int total}) _matchMetric(QuizSession session) {
    var correct = 0;
    var total = 0;
    for (final record in session.answeredRecords) {
      final question = record.question;
      final answer = record.answer;
      if (question is! MatchTheFollowingQuestion ||
          answer is! MatchTheFollowingAnswer) {
        continue;
      }
      total += question.pairs.length;
      for (final pair in question.pairs) {
        if (answer.matchedPairIds[pair.id] == pair.id) correct++;
      }
    }
    for (final question in session.questions.skip(
      session.answeredRecords.length,
    )) {
      if (question is MatchTheFollowingQuestion) total += question.pairs.length;
    }
    return (correct: correct, total: total);
  }

  ({int correct, int total}) _sortMetric(QuizSession session) {
    var correct = 0;
    var total = 0;
    for (final record in session.answeredRecords) {
      final question = record.question;
      final answer = record.answer;
      if (question is! SortItRightQuestion || answer is! SortAnswer) continue;
      total += question.itemsInOrder.length;
      final comparableLength =
          question.itemsInOrder.length < answer.orderedItems.length
          ? question.itemsInOrder.length
          : answer.orderedItems.length;
      for (var i = 0; i < comparableLength; i++) {
        if (question.itemsInOrder[i] == answer.orderedItems[i]) correct++;
      }
    }
    for (final question in session.questions.skip(
      session.answeredRecords.length,
    )) {
      if (question is SortItRightQuestion) {
        total += question.itemsInOrder.length;
      }
    }
    return (correct: correct, total: total);
  }
}
