import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/data/datasources/mock/auth_mock_datasource.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/data/datasources/mock/quiz_mock_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('wallet debit updates balance in real time', () async {
    final storage = await LocalStorageService.create();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authDatasourceProvider.overrideWithValue(AuthMockDatasource()),
        walletDatasourceProvider.overrideWithValue(WalletMockDatasource()),
      ],
    );
    addTearDown(container.dispose);

    // Log in default seeded user
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'test@example.com', password: 'password123');

    // Credit coins to wallet
    await container
        .read(walletControllerProvider.notifier)
        .credit(
          currency: CurrencyType.coins,
          amount: 100,
          reason: 'Starter test coins',
        );

    final balance1 = await container.read(walletControllerProvider.future);
    expect(balance1.coins, 100);

    // Debit for power-up
    final didDebit = await container
        .read(walletControllerProvider.notifier)
        .debit(
          currency: CurrencyType.coins,
          amount: 20,
          reason: 'In-game power-up: 50:50',
        );

    expect(didDebit, isTrue);
    final balance2 = await container.read(walletControllerProvider.future);
    expect(balance2.coins, 80);
  });

  test(
    'QuizController auto-disposes so a topic can be replayed cleanly',
    () async {
      final storage = await LocalStorageService.create();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          questionDatasourceProvider.overrideWithValue(
            QuestionMockDatasource(),
          ),
          quizDatasourceProvider.overrideWithValue(QuizMockDatasource()),
        ],
      );
      addTearDown(container.dispose);

      const request = QuizSessionRequest(
        topicId: 'accounting-chapter-1-topic-1',
        quizType: QuestionType.mcq,
      );

      // Read provider with subscription to simulate active screen
      final sub1 = container.listen(
        quizControllerProvider(request),
        (previous, next) {},
      );
      await container.pump();

      final state1 = container.read(quizControllerProvider(request));
      expect(state1.isLoading, isTrue);

      // Close subscription (simulating screen exit)
      sub1.close();
      await container.pump();

      // Opening again starts a fresh instance rather than keeping dead state
      final sub2 = container.listen(
        quizControllerProvider(request),
        (previous, next) {},
      );
      final state2 = container.read(quizControllerProvider(request));
      expect(state2.valueOrNull?.result, isNull);
      sub2.close();
    },
  );
}
