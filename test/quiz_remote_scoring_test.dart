import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer_evaluation.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/domain/entities/question_answer_record.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_session.dart';

class _FakeLocalStorage implements LocalStorageService {
  final Map<String, String> _map = {};

  @override
  String? getString(String key) => _map[key];

  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }
}

void main() {
  group('QuizRemoteDatasource Scoring Accuracy', () {
    late LocalStorageService storage;

    setUp(() {
      storage = _FakeLocalStorage();
    });

    test('evaluateAnswer uses backend fixed MCQ points', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/quiz/sessions/create')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Session created',
              'data': {
                'session': 'sess-123',
                'topic': 'accounting',
                'total_questions': 10,
                'questions': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/quiz/answers/evaluate')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Answer evaluated successfully',
              'data': {
                'question': 'q1',
                'option': 'a',
                'correct_option': 'a',
                'is_correct': true,
                'is_skipped': false,
                'points_earned': 10,
                'coins_earned': 0,
                'combo_streak': 1,
                'total_score': 10,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
        storage: storage,
        httpClient: mockClient,
      );

      final remote = QuizRemoteDatasource(apiClient: apiClient);
      const question = McqQuestion(
        id: 'q1',
        topicId: 'accounting',
        prompt: 'Test Question',
        points: 15,
        options: [
          QuestionOption(id: 'a', text: 'Option A'),
          QuestionOption(id: 'b', text: 'Option B'),
        ],
        correctOptionId: 'a',
      );

      final eval = await remote.evaluateAnswer(
        question,
        const McqAnswer(questionId: 'q1', selectedOptionId: 'a'),
      );

      expect(eval.isCorrect, isTrue);
      expect(eval.pointsEarned, 10);
    });

    test(
      'submitSession uses authoritative deterministic totals and breakdowns',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/complete')) {
            return http.Response(
              jsonEncode({
                'code': 200,
                'message': 'Completed',
                'data': {
                  'session': 'sess-123',
                  'total_questions': 10,
                  'correct_count': 5,
                  'accuracy_percentage': 50,
                  'final_score': 50,
                  'max_score': 100,
                  'coins_awarded': 15,
                  'xp_awarded': 35,
                  'gems_awarded': 0,
                  'score_breakdown': {'correct_answer_points': 50},
                  'xp_breakdown': {
                    'completion_xp': 10,
                    'correct_answer_xp': 25,
                    'perfect_bonus_xp': 0,
                  },
                  'coin_breakdown': {
                    'completion_coins': 5,
                    'correct_answer_coins': 10,
                    'perfect_bonus_coins': 0,
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: storage,
          httpClient: mockClient,
        );

        final remote = QuizRemoteDatasource(apiClient: apiClient);

        final questions = List.generate(
          10,
          (i) => McqQuestion(
            id: 'q$i',
            topicId: 'accounting',
            prompt: 'Question $i',
            points: 10,
            options: const [
              QuestionOption(id: 'a', text: 'Opt A'),
              QuestionOption(id: 'b', text: 'Opt B'),
            ],
            correctOptionId: 'a',
          ),
        );

        final answeredRecords = List.generate(
          10,
          (i) => QuestionAnswerRecord(
            question: questions[i],
            answer: McqAnswer(
              questionId: questions[i].id,
              selectedOptionId: i < 5 ? 'a' : 'b',
            ),
            evaluation: AnswerEvaluation(
              isCorrect: i < 5,
              pointsEarned: i < 5 ? 99 : 0,
            ),
          ),
        );

        final session = QuizSession(
          id: 'sess-123',
          userId: '1',
          topicId: 'accounting',
          quizType: QuestionType.mcq,
          questions: questions,
          answeredRecords: answeredRecords,
          endedEarly: false,
          startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
          completedAt: DateTime.now(),
        );

        final result = await remote.submitSession(session);

        expect(result.score.earnedPoints, 50);
        expect(result.score.maxPoints, 100);
        expect(result.score.correctCount, 5);
        expect(result.score.totalCount, 10);
        expect(result.score.percentage, 0.5);
        expect(result.accuracy, 0.5);
        expect(result.wrongCount, 5);
        expect(result.xpAwarded, 35);
        expect(result.coinsAwarded, 15);
        expect(result.rewardBreakdown.score.single.amount, 50);
        expect(
          result.rewardBreakdown.xp.fold<int>(
            0,
            (sum, item) => sum + item.amount,
          ),
          35,
        );
        expect(
          result.rewardBreakdown.coins.fold<int>(
            0,
            (sum, item) => sum + item.amount,
          ),
          15,
        );
      },
    );

    test('full 10/10 response preserves perfect score and bonuses', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/quiz/sessions/complete')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'Completed',
              'data': {
                'session': 'sess-789',
                'total_questions': 10,
                'correct_count': 10,
                'accuracy_percentage': 100,
                'final_score': 100,
                'max_score': 100,
                'coins_awarded': 35,
                'xp_awarded': 75,
                'gems_awarded': 3,
                'score_breakdown': {'correct_answer_points': 100},
                'xp_breakdown': {
                  'completion_xp': 10,
                  'correct_answer_xp': 50,
                  'perfect_bonus_xp': 15,
                },
                'coin_breakdown': {
                  'completion_coins': 5,
                  'correct_answer_coins': 20,
                  'perfect_bonus_coins': 10,
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(
        config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
        storage: storage,
        httpClient: mockClient,
      );

      final remote = QuizRemoteDatasource(apiClient: apiClient);

      final questions = List.generate(
        10,
        (i) => McqQuestion(
          id: 'q$i',
          topicId: 'accounting',
          prompt: 'Question $i',
          points: 10,
          options: const [
            QuestionOption(id: 'a', text: 'Opt A'),
            QuestionOption(id: 'b', text: 'Opt B'),
          ],
          correctOptionId: 'a',
        ),
      );

      final answeredRecords = List.generate(
        10,
        (i) => QuestionAnswerRecord(
          question: questions[i],
          answer: const McqAnswer(questionId: 'q0', selectedOptionId: 'a'),
          evaluation: const AnswerEvaluation(isCorrect: true, pointsEarned: 28),
        ),
      );

      final session = QuizSession(
        id: 'sess-789',
        userId: '1',
        topicId: 'accounting',
        quizType: QuestionType.mcq,
        questions: questions,
        answeredRecords: answeredRecords,
        endedEarly: false,
        startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        completedAt: DateTime.now(),
      );

      final result = await remote.submitSession(session);

      expect(result.score.earnedPoints, 100);
      expect(result.score.maxPoints, 100);
      expect(result.score.correctCount, 10);
      expect(result.score.totalCount, 10);
      expect(result.score.percentage, 1.0);
      expect(result.accuracy, 1.0);
      expect(result.wrongCount, 0);
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

    test(
      'zero backend score is authoritative and is not replaced locally',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/complete')) {
            return http.Response(
              jsonEncode({
                'code': 200,
                'message': 'Completed',
                'data': {
                  'session': 'sess-zero',
                  'total_questions': 10,
                  'correct_count': 0,
                  'accuracy_percentage': 0,
                  'final_score': 0,
                  'max_score': 100,
                  'coins_awarded': 5,
                  'xp_awarded': 10,
                  'gems_awarded': 0,
                  'score_breakdown': {'correct_answer_points': 99},
                  'xp_breakdown': {'completion_xp': 10, 'speed_bonus_xp': 108},
                  'coin_breakdown': {
                    'completion_coins': 5,
                    'accuracy_bonus_coins': 99,
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final remote = QuizRemoteDatasource(
          apiClient: ApiClient(
            config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
            storage: storage,
            httpClient: mockClient,
          ),
        );
        const question = McqQuestion(
          id: 'q1',
          topicId: 'accounting',
          prompt: 'Question',
          points: 99,
          options: [
            QuestionOption(id: 'a', text: 'A'),
            QuestionOption(id: 'b', text: 'B'),
          ],
          correctOptionId: 'a',
        );
        final session = QuizSession(
          id: 'sess-zero',
          topicId: 'accounting',
          quizType: QuestionType.mcq,
          questions: const [question],
          answeredRecords: const [
            QuestionAnswerRecord(
              question: question,
              answer: McqAnswer(questionId: 'q1', selectedOptionId: 'b'),
              evaluation: AnswerEvaluation(isCorrect: false, pointsEarned: 99),
            ),
          ],
          endedEarly: false,
          startedAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        );

        final result = await remote.submitSession(session);

        expect(result.score.earnedPoints, 0);
        expect(result.score.maxPoints, 100);
        expect(result.score.correctCount, 0);
        expect(result.wrongCount, 10);
        expect(result.rewardBreakdown.score, isEmpty);
        expect(result.rewardBreakdown.xp, isEmpty);
        expect(result.rewardBreakdown.coins, isEmpty);
      },
    );
  });
}
