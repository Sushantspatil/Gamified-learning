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
import 'package:skillverse_app/features/quiz/domain/entities/quiz_session.dart';
import 'package:skillverse_app/features/questions/domain/entities/answer.dart';

import 'package:skillverse_app/features/profile/data/datasources/remote/profile_remote_datasource.dart';
import 'package:skillverse_app/features/wallet/data/datasources/remote/wallet_remote_datasource.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';

void main() {
  group('Live Go Backend & Flutter End-to-End Integration', () {
    late LocalStorageService storage;
    late ApiClient apiClient;
    late AuthRemoteDatasource authRemote;
    late QuestionRemoteDatasource questionRemote;
    late QuizRemoteDatasource quizRemote;
    late ProfileRemoteDatasource profileRemote;
    late WalletRemoteDatasource walletRemote;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.create();
      final config = ApiConfig.defaultConfig();
      apiClient = ApiClient(config: config, storage: storage);
      authRemote = AuthRemoteDatasource(apiClient: apiClient, storage: storage);
      questionRemote = QuestionRemoteDatasource(apiClient: apiClient);
      quizRemote = QuizRemoteDatasource(apiClient: apiClient);
      profileRemote =
          ProfileRemoteDatasource(apiClient: apiClient, storage: storage);
      walletRemote = WalletRemoteDatasource(apiClient: apiClient);
    });

    tearDown(() {
      apiClient.close();
    });

    test(
      'Authenticate with Go backend, persist token, and fetch user session',
      () async {
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
      },
    );

    test(
      'Live Go Backend Sign up: request OTP, verify OTP, register user, and establish session',
      () async {
        final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
        final testEmail = 'player_$uniqueSuffix@example.com';
        const testPassword = 'SecretPass123!';
        final testName = 'Player$uniqueSuffix';

        // 1. Request verification OTP from backend
        final otp = await authRemote.requestSignUpOtp(
          email: testEmail,
          password: testPassword,
          displayName: testName,
        );
        expect(otp, isNotNull);
        expect(otp!.length, 6);

        // 2. Verify OTP with backend
        await authRemote.verifySignUpOtp(email: testEmail, otp: otp);

        // 3. Register user and log in to get session
        final user = await authRemote.signUp(
          email: testEmail,
          password: testPassword,
          displayName: testName,
        );

        expect(user.id, isNotEmpty);
        expect(user.email, testEmail);
        expect(user.displayName, testName);

        // 4. Verify auth tokens are saved to local storage
        final token = storage.getString(StorageKeys.authToken);
        expect(token, isNotNull);
        expect(token!, isNotEmpty);

        final currentUserId = storage.getString(StorageKeys.currentUserId);
        expect(currentUserId, user.id);

        // 5. Verify session can be retrieved using stored token
        final sessionUser = await authRemote.getUserById(user.id);
        expect(sessionUser, isNotNull);
        expect(sessionUser!.id, user.id);
        expect(sessionUser.email, testEmail);
      },
    );

    test(
      'Live MCQ Quiz lifecycle: fetch questions, create session, evaluate answer, and complete',
      () async {
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
            selectedOptionId: firstMcq.options.first.id,
          ),
        );

        expect(evaluation, isNotNull);
        expect(evaluation.isCorrect, isA<bool>());
        expect(evaluation.pointsEarned, isA<int>());

        // 5. Test 50:50 power-up live from backend
        final hiddenOptions = await quizRemote.applyFiftyFifty(firstMcq.id);
        expect(hiddenOptions, isNotNull);
        expect(hiddenOptions!.length, 2);

        // 6. Complete session with backend
        final sessionResult = await quizRemote.submitSession(
          QuizSession(
            id: sessionId,
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
        expect(sessionResult.score.totalCount, greaterThanOrEqualTo(1));
      },
    );

    test('Live Profile lifecycle: fetch profile, update avatar, and complete setup', () async {
      final user = await authRemote.login(
        email: 'player@example.com',
        password: 'secretpassword123',
      );

      final initialProfile = await profileRemote.getProfile(user.id);
      expect(initialProfile, isNotNull);

      final updatedProfile = await profileRemote.updateAvatar(
        userId: user.id,
        avatarId: 'paw',
      );
      expect(updatedProfile.avatarId, 'paw');

      final completedProfile = await profileRemote.completeProfileSetup(
        userId: user.id,
        avatarId: 'paw',
        classLevel: '12th',
        board: 'CBSE',
        selectedSubjectIds: ['accounting'],
      );
      expect(completedProfile.classLevel, '12th');
      expect(completedProfile.board, 'CBSE');
      expect(completedProfile.profileSetupCompleted, isTrue);
    });

    test('Live Wallet lifecycle: check balance, credit, debit, and fetch transactions', () async {
      final user = await authRemote.login(
        email: 'player@example.com',
        password: 'secretpassword123',
      );

      final initialBalance = await walletRemote.getBalance(user.id);
      expect(initialBalance.coins, greaterThanOrEqualTo(0));

      final creditTxn = await walletRemote.credit(
        userId: user.id,
        currency: CurrencyType.coins,
        amount: 50,
        reason: 'Daily streak reward',
      );
      expect(creditTxn.amount, 50);

      final debitTxn = await walletRemote.debit(
        userId: user.id,
        currency: CurrencyType.coins,
        amount: 20,
        reason: 'Purchased power-up',
      );
      expect(debitTxn.amount, 20);

      final balanceAfter = await walletRemote.getBalance(user.id);
      expect(balanceAfter.coins, equals(initialBalance.coins + 30));

      final history = await walletRemote.getTransactionHistory(user.id);
      expect(history, isNotEmpty);
    });
  });
}
