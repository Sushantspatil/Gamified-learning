import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/authentication/data/datasources/remote/auth_remote_datasource.dart';
import 'package:skillverse_app/features/questions/data/datasources/remote/question_remote_datasource.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/domain/entities/quiz_session.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';

void main() {
  group('Live Go Backend & Flutter End-to-End Integration', () {
    late LocalStorageService storage;
    late ApiClient apiClient;
    late AuthRemoteDatasource authRemote;
    late QuestionRemoteDatasource questionRemote;
    late QuizRemoteDatasource quizRemote;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      final config = ApiConfig(baseUrl: 'http://127.0.0.1:8080/api/v1');
      apiClient = ApiClient(config: config, storage: storage);
      authRemote = AuthRemoteDatasource(apiClient: apiClient, storage: storage);
      questionRemote = QuestionRemoteDatasource(apiClient: apiClient);
      quizRemote = QuizRemoteDatasource(
        apiClient: apiClient,
        fallbackDatasource: QuizMockDatasource(),
      );
    });

    tearDown(() {
      apiClient.close();
    });

    test('Authenticate with Go backend, persist token, and fetch user session', () async {
      // 1. Live login against running backend
      final user = await authRemote.login(
        email: 'player@example.com',
        password: 'secretpassword123',
      );

      expect(user.id, isNotEmpty);
      expect(user.email, 'player@example.com');
      expect(user.displayName, isNotEmpty);

      // 2. Token persistence verified
      final token = storage.getString(StorageKeys.authToken);
      expect(token, isNotNull);
      expect(token!, isNotEmpty);

      // 3. Verify session endpoint using persisted token
      final verifiedUser = await authRemote.getUserById(user.id);
      expect(verifiedUser, isNotNull);
      expect(verifiedUser!.id, user.id);
      expect(verifiedUser.email, 'player@example.com');
    });

    test('Live MCQ Quiz lifecycle: fetch questions, create session, evaluate answer, and complete', () async {
      // 1. Authenticate to populate Bearer token
      await authRemote.login(
        email: 'player@example.com',
        password: 'secretpassword123',
      );

      // 2. Fetch live questions from PostgreSQL
      final questions = await questionRemote.getQuestionsForTopicAndType(
        'accounting',
        QuestionType.mcq,
      );

      expect(questions, isNotEmpty);
      expect(questions.first, isA<McqQuestion>());
      final firstMcq = questions.first as McqQuestion;
      expect(firstMcq.options.length, 4);

      // 3. Create a live server-side quiz session
      final sessionId = await quizRemote.createSession(
        topicId: 'accounting',
        questionCount: 3,
      );

      expect(sessionId, isNotNull);
      expect(quizRemote.activeSessionId, sessionId);

      // 4. Submit an answer for evaluation to the backend
      final evaluation = await quizRemote.evaluateAnswer(
        firstMcq,
        McqAnswer(
          questionId: firstMcq.id,
          selectedOptionId: firstMcq.correctOptionId,
        ),
      );

      expect(evaluation.isCorrect, isTrue);
      expect(evaluation.pointsEarned, greaterThan(0));

      // 5. Complete session with backend
      final sessionResult = await quizRemote.submitSession(
        QuizSession(
          id: sessionId!,
          userId: '1',
          topicId: 'accounting',
          quizType: QuestionType.mcq,
          questions: questions.take(3).toList(),
          answeredRecords: [],
          endedEarly: false,
          startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
          completedAt: DateTime.now(),
        ),
      );

      expect(sessionResult.sessionId, sessionId);
      expect(sessionResult.score.earnedPoints, greaterThan(0));
    });
  });
}
