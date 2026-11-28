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

  /// Every accepted request: (user, reason, reference id).
  final List<(String, String, String?)> calls = [];

  /// Apply the next credit, then fail as if the response was lost.
  bool loseNextResponse = false;

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
    String? referenceId,
  }) async {
    if (offline) throw const NetworkException();
    if (currency == CurrencyType.coins) {
      coins += amount;
    } else {
      gems += amount;
    }
    log.add('+$amount ${currency.name} $reason');
    calls.add((userId, reason, referenceId));
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const NetworkException();
    }
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
    String? referenceId,
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
    calls.add((userId, reason, referenceId));
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

/// Signed in as whoever the test says; starts as u1.
class _Switchable extends AuthController {
  @override
  Future<AppUser?> build() async =>
      const AppUser(id: 'u1', email: 'a@b.c', displayName: 'Ada');

  void signInAs(String? id) => state = AsyncData(
    id == null ? null : AppUser(id: id, email: '$id@b.c', displayName: id),
  );
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

  test(
    'a retried credit keeps its reference id; each entry has its own',
    () async {
      final account = _Account(coins: 3165, gems: 237);
      final container = await start(account);
      final rewards = container.read(rewardsProvider.notifier);

      // Applied by the account, but the answer is lost: it will be sent again.
      account.loseNextResponse = true;
      rewards.startSpin();
      rewards.completeSpin();
      await _settle();
      container.invalidate(walletControllerProvider);
      await _settle();

      final spins = account.calls.where((c) => c.$2 == 'spin_wheel').toList();
      expect(spins, hasLength(2));
      expect(spins.first.$3, isNotNull);
      expect(spins.first.$3!.length, lessThanOrEqualTo(64));
      expect(spins.last.$3, spins.first.$3); // same id: the server can dedupe

      rewards.purchase('avatar-scholar');
      await _settle();
      final shop = account.calls.last;
      expect(shop.$2, 'shop_avatar-scholar');
      expect(shop.$3, isNot(spins.first.$3));
    },
  );

  test('a chest whose price is refused pays no prize', () async {
    final account = _Account(coins: 3165, gems: 237);
    final container = await start(account, random: 5);
    // Spent elsewhere: the phone still thinks 3165, the account has 50.
    account.coins = 50;

    final result = container
        .read(rewardsProvider.notifier)
        .forceOpenChest(ChestTier.golden); // costs 200
    expect(result.status, ChestOpenStatus.opened);
    await _settle();

    expect(account.log, isEmpty); // debit refused, prize never sent
    expect(account.coins, 50);
    expect(container.read(rewardsProvider).coins, 50);
  });

  test(
    "one account's queued spend is never sent under another account",
    () async {
      final account = _Account(coins: 3165, gems: 237)..offline = true;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authControllerProvider.overrideWith(_Switchable.new),
          walletDatasourceProvider.overrideWithValue(account),
          rewardsRandomProvider.overrideWithValue(_FixedRandom(9)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(rewardsProvider, (_, _) {});
      container.listen(walletControllerProvider, (_, _) {});
      await _settle();
      final auth =
          container.read(authControllerProvider.notifier) as _Switchable;

      // u1 buys while offline: the debit waits in the queue.
      container.read(rewardsProvider.notifier).purchase('avatar-scholar');
      await _settle();
      expect(account.calls, isEmpty);

      // u1 signs out and u2 signs in with a working connection.
      auth.signInAs(null);
      await _settle();
      account.offline = false;
      auth.signInAs('u2');
      await _settle();
      expect(account.calls, isEmpty); // nothing charged to u2
      expect(container.read(rewardsProvider).coins, 3165); // u2's own balance

      // u1 comes back: their spend is sent under their own account.
      auth.signInAs('u1');
      await _settle();
      expect(account.calls.single.$1, 'u1');
      expect(account.calls.single.$2, 'shop_avatar-scholar');
    },
  );
}
