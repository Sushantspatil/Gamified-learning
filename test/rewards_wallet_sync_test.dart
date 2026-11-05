import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/rewards/domain/rewards_models.dart';
import 'package:skillverse_app/features/wallet/data/datasources/wallet_datasource.dart';
import 'package:skillverse_app/features/wallet/data/models/wallet_balance_model.dart';
import 'package:skillverse_app/features/wallet/data/models/wallet_transaction_model.dart';
import 'package:skillverse_app/features/wallet/domain/entities/currency_type.dart';
import 'package:skillverse_app/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:skillverse_app/features/wallet/presentation/providers/wallet_providers.dart';

/// A stand-in for the account: it holds the real balance, remembers what was
/// sent to it, and can be told to fail like a dropped connection.
class _Account implements WalletDatasource {
  int coins;
  int gems;
  bool offline = false;
  final List<String> log = [];

  _Account({required this.coins, required this.gems});

  @override
  Future<WalletBalanceModel> getBalance(String userId) async =>
      WalletBalanceModel(coins: coins, gems: gems);

  WalletTransactionModel _entry(
    String userId,
    CurrencyType currency,
    TransactionDirection direction,
    int amount,
    String reason,
  ) => WalletTransactionModel(
    id: 't${log.length}',
    userId: userId,
    currency: currency,
    direction: direction,
    amount: amount,
    reason: reason,
    balanceAfter: currency == CurrencyType.coins ? coins : gems,
    createdAt: DateTime(2026),
  );

  @override
  Future<WalletTransactionModel> credit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    if (offline) throw const NetworkException();
    if (currency == CurrencyType.coins) {
      coins += amount;
    } else {
      gems += amount;
    }
    log.add('+$amount ${currency.name} $reason');
    return _entry(
      userId,
      currency,
      TransactionDirection.credit,
      amount,
      reason,
    );
  }

  @override
  Future<WalletTransactionModel> debit({
    required String userId,
    required CurrencyType currency,
    required int amount,
    required String reason,
  }) async {
    if (offline) throw const NetworkException();
    final have = currency == CurrencyType.coins ? coins : gems;
    if (have < amount) throw const ValidationException('Not enough funds.');
    if (currency == CurrencyType.coins) {
      coins -= amount;
    } else {
      gems -= amount;
    }
    log.add('-$amount ${currency.name} $reason');
    return _entry(userId, currency, TransactionDirection.debit, amount, reason);
  }

  @override
  Future<List<WalletTransactionModel>> getTransactionHistory(
    String userId,
  ) async => const [];
}

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async =>
      const AppUser(id: 'u1', email: 'a@b.c', displayName: 'Ada');
}

class _FixedRandom implements math.Random {
  final int index;
  _FixedRandom(this.index);
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => index;
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The same numbers must show everywhere: the account's, not a private count.
void main() {
  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
  });

  Future<ProviderContainer> start(_Account account, {int random = 9}) async {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        authControllerProvider.overrideWith(_SignedIn.new),
        walletDatasourceProvider.overrideWithValue(account),
        rewardsRandomProvider.overrideWithValue(_FixedRandom(random)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(rewardsProvider, (_, _) {});
    container.listen(walletControllerProvider, (_, _) {});
    await _settle();
    return container;
  }

  test('the balance shown is the account balance', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account);
    final rewards = container.read(rewardsProvider);
    expect(rewards.coins, 3165);
    expect(rewards.gems, 237);
    expect(container.read(walletControllerProvider).value!.coins, 3165);
  });

  test('a spin prize is paid into the account, once', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account);
    final rewards = container.read(rewardsProvider.notifier);

    expect(rewards.startSpin(), 9); // the 30-coin segment
    expect(rewards.completeSpin(), 30);
    // Shown at once, before the account has answered.
    expect(container.read(rewardsProvider).coins, 3195);
    await _settle();

    expect(account.coins, 3195);
    expect(account.log, ['+30 coins spin_wheel']);
    expect(container.read(rewardsProvider).coins, 3195);
    expect(container.read(walletControllerProvider).value!.coins, 3195);
  });

  test('buying takes the price from the account', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account);

    final outcome = container
        .read(rewardsProvider.notifier)
        .purchase('avatar-scholar'); // 100 coins
    expect(outcome, PurchaseOutcome.success);
    await _settle();

    expect(account.coins, 3065);
    expect(container.read(rewardsProvider).coins, 3065);
    expect(container.read(walletControllerProvider).value!.coins, 3065);
  });

  test('a chest bought early takes coins and pays its prize', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account, random: 5);

    final result = container
        .read(rewardsProvider.notifier)
        .forceOpenChest(ChestTier.golden); // costs 200
    expect(result.status, ChestOpenStatus.opened);
    final prize = result.reward!.coins;
    await _settle();

    expect(account.coins, 3165 - 200 + prize);
    expect(container.read(rewardsProvider).coins, account.coins);
  });

  test('gems from a Galaxy chest go to the account too', () async {
    final account = _Account(coins: 5000, gems: 237);
    final container = await start(account, random: 4);

    final result = container
        .read(rewardsProvider.notifier)
        .forceOpenChest(ChestTier.galaxy); // costs 1000
    final gems = result.reward!.gems;
    await _settle();

    expect(account.gems, 237 + gems);
    expect(account.coins, 4000);
    expect(container.read(rewardsProvider).gems, 237 + gems);
  });

  test(
    'with no connection the prize waits, shows, and is paid later',
    () async {
      final account = _Account(coins: 3165, gems: 237)..offline = true;
      final container = await start(account);
      final rewards = container.read(rewardsProvider.notifier);

      rewards.startSpin();
      rewards.completeSpin();
      await _settle();
      // Not delivered yet, but the player still sees what they won.
      expect(account.coins, 3165);
      expect(container.read(rewardsProvider).coins, 3195);

      // The connection returns: the next time the balance loads, it is sent.
      account.offline = false;
      container.invalidate(walletControllerProvider);
      await _settle();
      expect(account.coins, 3195);
      expect(container.read(rewardsProvider).coins, 3195);
      expect(account.log, ['+30 coins spin_wheel']);
    },
  );

  test('a refused spend is dropped and the true balance returns', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account);
    // Coins were spent elsewhere meanwhile, so the account has too little.
    account.coins = 50;
    final outcome = container
        .read(rewardsProvider.notifier)
        .purchase('avatar-scholar'); // the phone still thinks 3165
    expect(outcome, PurchaseOutcome.success);
    await _settle();

    expect(account.coins, 50); // the account refused to go negative
    expect(container.read(rewardsProvider).coins, 50);
  });
}
