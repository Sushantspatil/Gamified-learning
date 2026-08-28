import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/wallet/data/datasources/mock/wallet_mock_datasource.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';
import 'package:skillverse_app/features/wallet/domain/entities/wallet_transaction.dart';

void main() {
  test('credit increases balance and records a ledger entry', () async {
    final datasource = WalletMockDatasource();

    final txn = await datasource.credit(
      userId: 'u1',
      currency: CurrencyType.coins,
      amount: 50,
      reason: 'Quiz reward',
    );

    expect(txn.direction, TransactionDirection.credit);
    expect(txn.balanceAfter, 50);

    final balance = await datasource.getBalance('u1');
    expect(balance.coins, 50);

    final history = await datasource.getTransactionHistory('u1');
    expect(history, hasLength(1));
    expect(history.first.reason, 'Quiz reward');
  });

  test('debit decreases balance when funds are sufficient', () async {
    final datasource = WalletMockDatasource();
    await datasource.credit(
      userId: 'u1',
      currency: CurrencyType.gems,
      amount: 30,
      reason: 'Seed',
    );

    final txn = await datasource.debit(
      userId: 'u1',
      currency: CurrencyType.gems,
      amount: 20,
      reason: 'Shop purchase',
    );

    expect(txn.direction, TransactionDirection.debit);
    expect(txn.balanceAfter, 10);
  });

  test(
    'debit throws and leaves balance untouched when funds are insufficient',
    () async {
      final datasource = WalletMockDatasource();
      await datasource.credit(
        userId: 'u1',
        currency: CurrencyType.coins,
        amount: 10,
        reason: 'Seed',
      );

      await expectLater(
        datasource.debit(
          userId: 'u1',
          currency: CurrencyType.coins,
          amount: 100,
          reason: 'Too much',
        ),
        throwsA(anything),
      );

      final balance = await datasource.getBalance('u1');
      expect(balance.coins, 10); // unchanged
      expect(
        await datasource.getTransactionHistory('u1'),
        hasLength(1),
      ); // no debit entry recorded
    },
  );

  test('transaction history is returned most-recent-first', () async {
    final datasource = WalletMockDatasource();
    await datasource.credit(
      userId: 'u1',
      currency: CurrencyType.coins,
      amount: 10,
      reason: 'First',
    );
    await datasource.credit(
      userId: 'u1',
      currency: CurrencyType.coins,
      amount: 20,
      reason: 'Second',
    );

    final history = await datasource.getTransactionHistory('u1');
    expect(history.map((t) => t.reason), ['Second', 'First']);
  });
}
