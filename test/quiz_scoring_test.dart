import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/domain/entities/question_answer_record.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_session.dart';

void main() {
  final datasource = QuizMockDatasource();

  test(
    'missed sort items earn no points and remain aligned with later answers',
    () async {
      const question = SortItRightQuestion(
        id: 'misses',
        topicId: 't',
        prompt: 'Sort',
        points: 10,
        itemsInOrder: ['A', 'B', 'C', 'D', 'E'],
        correctSides: [
          SortSide.left,
          SortSide.right,
          SortSide.left,
          SortSide.right,
          SortSide.left,
        ],
      );
      const answer = SortAnswer(
        questionId: 'misses',
        orderedItems: ['A', 'B', 'C', 'D', 'E'],
        selectedSides: [
          null,
          SortSide.right,
          null,
          SortSide.right,
          SortSide.left,
        ],
      );
      final evaluation = await datasource.evaluateAnswer(question, answer);
      expect(evaluation.pointsEarned, 6);
      expect(evaluation.isCorrect, isFalse);
      final result = await datasource.submitSession(
        QuizSession(
          id: 'missed-session',
          topicId: 't',
          quizType: QuestionType.sortItRight,
          questions: const [question],
          answeredRecords: [
            QuestionAnswerRecord(
              question: question,
              answer: answer,
              evaluation: evaluation,
            ),
          ],
          endedEarly: false,
          startedAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
      );
      expect(result.score.correctCount, 3);
      expect(result.wrongCount, 2);
      expect(result.accuracy, .6);
    },
  );

  test(
    'Sort It Out loads five mapped items and scores classifications',
    () async {
      final questions = await QuestionMockDatasource()
          .getQuestionsForTopicAndType('topic', QuestionType.sortItRight);
      final question = questions.single as SortItRightQuestion;
      expect(question.itemsInOrder.length, greaterThanOrEqualTo(5));
      expect(question.hasCategories, isTrue);
      final correct = SortAnswer(
        questionId: question.id,
        orderedItems: question.itemsInOrder,
        selectedSides: question.correctSides,
      );
      final evaluation = await datasource.evaluateAnswer(question, correct);
      expect(evaluation.pointsEarned, 10);
      final partial = SortAnswer(
        questionId: question.id,
        orderedItems: question.itemsInOrder,
        selectedSides: [SortSide.right, ...question.correctSides.skip(1)],
      );
      final partialEvaluation = await datasource.evaluateAnswer(
        question,
        partial,
      );
      expect(partialEvaluation.pointsEarned, 8);
      expect(partialEvaluation.isCorrect, isFalse);
      final wrong = await datasource.evaluateAnswer(
        question,
        SortAnswer(
          questionId: question.id,
          orderedItems: question.itemsInOrder,
          selectedSides: question.correctSides
              .map(
                (side) =>
                    side == SortSide.left ? SortSide.right : SortSide.left,
              )
              .toList(),
        ),
      );
      expect(wrong.pointsEarned, 0);
      final result = await datasource.submitSession(
        QuizSession(
          id: 'sort-result',
          topicId: 'topic',
          quizType: QuestionType.sortItRight,
          questions: [question],
          answeredRecords: [
            QuestionAnswerRecord(
              question: question,
              answer: partial,
              evaluation: partialEvaluation,
            ),
          ],
          endedEarly: false,
          startedAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
      );
      expect(result.score.correctCount, 4);
      expect(result.wrongCount, 1);
      expect(result.accuracy, 0.8);
      expect(result.score.earnedPoints, 8);
    },
  );

  group('MCQ scoring', () {
    const question = McqQuestion(
      id: 'q1',
      topicId: 't1',
      prompt: 'p',
      points: 25,
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

    test(
      'partial result uses fixed MCQ score, XP, and coin formulas',
      () async {
        final questions = List.generate(
          10,
          (index) => McqQuestion(
            id: 'q$index',
            topicId: 't1',
            prompt: 'Question $index',
            points: 25,
            options: const [
              QuestionOption(id: 'a', text: 'A'),
              QuestionOption(id: 'b', text: 'B'),
            ],
            correctOptionId: 'a',
          ),
        );
        final records = List.generate(
          5,
          (index) => QuestionAnswerRecord(
            question: questions[index],
            answer: McqAnswer(
              questionId: questions[index].id,
              selectedOptionId: 'a',
            ),
            evaluation: const AnswerEvaluation(
              isCorrect: true,
              pointsEarned: 10,
            ),
          ),
        );

        final result = await datasource.submitSession(
          QuizSession(
            id: 'mcq-partial',
            topicId: 't1',
            quizType: QuestionType.mcq,
            questions: questions,
            answeredRecords: records,
            endedEarly: false,
            startedAt: DateTime(2026),
            completedAt: DateTime(2026, 1, 1, 0, 1),
          ),
        );

        expect(result.score.earnedPoints, 50);
        expect(result.score.maxPoints, 100);
        expect(result.score.correctCount, 5);
        expect(result.wrongCount, 5);
        expect(result.accuracy, .5);
        expect(result.xpAwarded, 35);
        expect(result.coinsAwarded, 15);
        expect(
          result.rewardBreakdown.xp
              .singleWhere((item) => item.key == 'perfect_bonus_xp')
              .amount,
          0,
        );
        expect(
          result.rewardBreakdown.coins
              .singleWhere((item) => item.key == 'perfect_bonus_coins')
              .amount,
          0,
        );
      },
    );

    test('perfect result includes only the fixed perfect bonuses', () async {
      final questions = List.generate(
        10,
        (index) => McqQuestion(
          id: 'perfect-$index',
          topicId: 't1',
          prompt: 'Question $index',
          points: 40,
          options: const [
            QuestionOption(id: 'a', text: 'A'),
            QuestionOption(id: 'b', text: 'B'),
          ],
          correctOptionId: 'a',
        ),
      );
      final records = questions
          .map(
            (question) => QuestionAnswerRecord(
              question: question,
              answer: McqAnswer(questionId: question.id, selectedOptionId: 'a'),
              evaluation: const AnswerEvaluation(
                isCorrect: true,
                pointsEarned: 10,
              ),
            ),
          )
          .toList();

      final result = await datasource.submitSession(
        QuizSession(
          id: 'mcq-perfect',
          topicId: 't1',
          quizType: QuestionType.mcq,
          questions: questions,
          answeredRecords: records,
          endedEarly: false,
          startedAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
      );

      expect(result.score.earnedPoints, 100);
      expect(result.score.maxPoints, 100);
      expect(result.xpAwarded, 75);
      expect(result.coinsAwarded, 35);
      expect(
        result.rewardBreakdown.xp
            .singleWhere((item) => item.key == 'perfect_bonus_xp')
            .amount,
        15,
      );
      expect(
        result.rewardBreakdown.coins
            .singleWhere((item) => item.key == 'perfect_bonus_coins')
            .amount,
        10,
      );
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
      const secondMcq = McqQuestion(
        id: 'q2',
        topicId: 't1',
        prompt: 'p2',
        points: 25,
        options: [
          QuestionOption(id: 'a', text: 'A'),
          QuestionOption(id: 'b', text: 'B'),
        ],
        correctOptionId: 'a',
      );

      final session = QuizSession(
        id: 'session-1',
        topicId: 't1',
        quizType: QuestionType.mcq,
        questions: const [mcq, secondMcq],
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
      expect(result.score.maxPoints, 20);
      expect(result.score.correctCount, 1);
      expect(result.score.totalCount, 2);
      expect(result.endedEarly, isTrue);
    },
  );
}
