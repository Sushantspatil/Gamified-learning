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

    test(
      'evaluateAnswer returns pointsEarned computed by backend CalculatePoints algorithm',
      () async {
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
                  'points_earned': 23, // CalculatePoints(15, 2, 3000, 1) = 23
                  'coins_earned': 5,
                  'combo_streak': 1,
                  'total_score': 23,
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
        expect(eval.pointsEarned, 23); // Uses proper CalculatePoints score
      },
    );

    test(
      'submitSession uses authoritative CalculatePoints total score and maxScore',
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
                  'correct_count': 3,
                  'final_score': 82, // 3 correct answers scored with CalculatePoints
                  'max_score': 280, // Total achievable score with perfect speed & combo
                  'coins_awarded': 17,
                  'xp_awarded': 51,
                  'gems_awarded': 0,
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
              selectedOptionId: i < 3 ? 'a' : 'b',
            ),
            evaluation: AnswerEvaluation(
              isCorrect: i < 3,
              pointsEarned: i == 0 ? 23 : (i == 1 ? 23 : (i == 2 ? 36 : 0)),
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

        // Check accurate points calculation from CalculatePoints
        expect(result.score.earnedPoints, 82);
        expect(result.score.maxPoints, 280);
        expect(result.score.correctCount, 3);
        expect(result.score.totalCount, 10);
        expect(result.score.percentage, closeTo(82 / 280, 0.001));
        expect(result.accuracy, 0.3);
        expect(result.wrongCount, 7);
      },
    );

    test(
      'Full 10/10 correct answers achieves perfect 280 / 280 score',
      () async {
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
                  'final_score': 280,
                  'max_score': 280,
                  'coins_awarded': 56,
                  'xp_awarded': 140,
                  'gems_awarded': 3,
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
            answer: const McqAnswer(
              questionId: 'q0',
              selectedOptionId: 'a',
            ),
            evaluation: const AnswerEvaluation(
              isCorrect: true,
              pointsEarned: 28,
            ),
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

        expect(result.score.earnedPoints, 280);
        expect(result.score.maxPoints, 280);
        expect(result.score.correctCount, 10);
        expect(result.score.totalCount, 10);
        expect(result.score.percentage, 1.0);
        expect(result.accuracy, 1.0);
        expect(result.wrongCount, 0);
      },
    );
  });
}
