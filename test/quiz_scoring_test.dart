import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/domain/entities/question_answer_record.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_session.dart';

void main() {
  final datasource = QuizMockDatasource();

  group('MCQ scoring', () {
    const question = McqQuestion(
      id: 'q1',
      topicId: 't1',
      prompt: 'p',
      points: 10,
      options: [
        QuestionOption(id: 'a', text: 'A'),
        QuestionOption(id: 'b', text: 'B'),
      ],
      correctOptionId: 'b',
    );

    test('correct option earns full points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const McqAnswer(questionId: 'q1', selectedOptionId: 'b'),
      );
      expect(evaluation.isCorrect, isTrue);
      expect(evaluation.pointsEarned, 10);
    });

    test('incorrect option earns zero points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const McqAnswer(questionId: 'q1', selectedOptionId: 'a'),
      );
      expect(evaluation.isCorrect, isFalse);
      expect(evaluation.pointsEarned, 0);
    });
  });

  group('Match the Following scoring', () {
    const question = MatchTheFollowingQuestion(
      id: 'q2',
      topicId: 't1',
      prompt: 'p',
      points: 12,
      pairs: [
        MatchPair(id: 'p1', left: 'L1', right: 'R1'),
        MatchPair(id: 'p2', left: 'L2', right: 'R2'),
        MatchPair(id: 'p3', left: 'L3', right: 'R3'),
      ],
    );

    test('all correct pairs earns full points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const MatchTheFollowingAnswer(
          questionId: 'q2',
          matchedPairIds: {'p1': 'p1', 'p2': 'p2', 'p3': 'p3'},
        ),
      );
      expect(evaluation.isCorrect, isTrue);
      expect(evaluation.pointsEarned, 12);
    });

    test('partially correct pairs earns proportional points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const MatchTheFollowingAnswer(
          questionId: 'q2',
          matchedPairIds: {'p1': 'p1', 'p2': 'p3', 'p3': 'p2'},
        ),
      );
      expect(evaluation.isCorrect, isFalse);
      expect(evaluation.pointsEarned, 4); // 1/3 of 12, rounded
    });
  });

  group('Sort It Right scoring', () {
    const question = SortItRightQuestion(
      id: 'q3',
      topicId: 't1',
      prompt: 'p',
      points: 10,
      itemsInOrder: ['A', 'B', 'C'],
    );

    test('correct order earns full points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const SortAnswer(questionId: 'q3', orderedItems: ['A', 'B', 'C']),
      );
      expect(evaluation.isCorrect, isTrue);
      expect(evaluation.pointsEarned, 10);
    });

    test('partial correct positions earn proportional points', () async {
      final evaluation = await datasource.evaluateAnswer(
        question,
        const SortAnswer(questionId: 'q3', orderedItems: ['B', 'A', 'C']),
      );
      expect(evaluation.isCorrect, isFalse);
      expect(evaluation.pointsEarned, 3); // 1/3 of 10, rounded
    });
  });

  test(
    'submitSession aggregates earned/max points and correct count',
    () async {
      const mcq = McqQuestion(
        id: 'q1',
        topicId: 't1',
        prompt: 'p',
        points: 10,
        options: [
          QuestionOption(id: 'a', text: 'A'),
          QuestionOption(id: 'b', text: 'B'),
        ],
        correctOptionId: 'b',
      );
      const sort = SortItRightQuestion(
        id: 'q3',
        topicId: 't1',
        prompt: 'p',
        points: 5,
        itemsInOrder: ['A', 'B'],
      );

      final session = QuizSession(
        id: 'session-1',
        topicId: 't1',
        quizType: QuestionType.mcq,
        questions: const [mcq, sort],
        answeredRecords: [
          QuestionAnswerRecord(
            question: mcq,
            answer: const McqAnswer(questionId: 'q1', selectedOptionId: 'b'),
            evaluation: const AnswerEvaluation(
              isCorrect: true,
              pointsEarned: 10,
            ),
          ),
        ],
        endedEarly: true,
        startedAt: DateTime(2026),
        completedAt: DateTime(2026, 1, 1, 0, 1),
      );

      final result = await datasource.submitSession(session);

      expect(result.score.earnedPoints, 10);
      expect(
        result.score.maxPoints,
        15,
      ); // includes the un-answered sort question's points
      expect(result.score.correctCount, 1);
      expect(result.score.totalCount, 2);
      expect(result.endedEarly, isTrue);
    },
  );
}
