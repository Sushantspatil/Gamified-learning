import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/date_key.dart';
import '../../authentication/presentation/providers/auth_providers.dart';
import '../../wallet/domain/entities/currency_type.dart';
import '../../wallet/domain/entities/wallet_balance.dart';
import '../../wallet/presentation/providers/wallet_providers.dart';
import '../data/rewards_catalog.dart';
import '../data/rewards_store.dart';
import '../domain/rewards_models.dart';

/// Injectable so tests control "today" and the spin result.
final rewardsClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final rewardsRandomProvider = Provider<Random>((ref) => Random());

/// One coin or gem movement waiting to be sent to the account.
class _WalletOp {
  final CurrencyType currency;

  /// Positive credits the account, negative debits it.
  final int amount;
  final String reason;

  const _WalletOp(this.currency, this.amount, this.reason);

  Map<String, Object> toJson() => {
    'c': currency == CurrencyType.coins ? 'coins' : 'gems',
    'a': amount,
    'r': reason,
  };

  static _WalletOp? fromJson(Object? json) {
    if (json is! Map) return null;
    final amount = json['a'];
    final reason = json['r'];
    if (amount is! int || amount == 0 || reason is! String) return null;
    return _WalletOp(
      json['c'] == 'gems' ? CurrencyType.gems : CurrencyType.coins,
      amount,
      reason,
    );
  }
}

/// The single place that changes coins, spins, chest progress and the
/// inventory. Every change is applied in one synchronous step and then
/// saved, so repeated taps and callbacks cannot double-award or double-buy.
///
/// Coins and gems belong to the player's account (the wallet). When someone
/// is signed in, the balance shown here is the account's balance, and every
/// win or spend is sent to the account, so every screen shows the same
/// numbers. Each change shows at once and is sent in the background; if the
/// network is down it waits in a saved queue and goes out later.
class RewardsController extends Notifier<RewardsState> {
  late RewardsStore _store;

  static const String _outboxKey = 'rewards_wallet_outbox_v1';
  LocalStorageService? _storage;
  final List<_WalletOp> _outbox = [];
  bool _flushing = false;
  bool _disposed = false;

  /// Whether the coins are the account's (someone is signed in).
  bool get _walletLive {
    try {
      return ref.read(authControllerProvider).valueOrNull != null;
    } catch (_) {
      return false;
    }
  }

  @override
  RewardsState build() {
    LocalStorageService? storage;
    try {
      storage = ref.read(localStorageServiceProvider);
    } catch (_) {
      storage = null; // not provided (e.g. some tests): keep in memory
    }
    _store = RewardsStore(storage);
    _storage = storage;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _loadOutbox();

    final saved = _store.load();
    var initial =
        saved ?? const RewardsState(coins: RewardsState.startingCoins);

    // The app was closed mid-spin: the prize was already chosen and the
    // day's spin used, so pay it now (exactly once).
    final pending = initial.pendingSpinReward;
    if (pending != null) {
      initial = initial.copyWith(
        coins: initial.coins + pending,
        clearPendingSpin: true,
      );
      _enqueue(CurrencyType.coins, pending, 'spin_wheel');
    }

    // Follow the account: its balance replaces this phone's own count, and
    // anything still waiting to be sent is added on top.
    try {
      ref.listen<AsyncValue<WalletBalance>>(walletControllerProvider, (
        previous,
        next,
      ) {
        if (next.isLoading || !next.hasValue || !_walletLive) return;
        _syncFromWallet(next.requireValue);
        _flushOutbox();
      });
      final wallet = ref.read(walletControllerProvider);
      if (_walletLive && !wallet.isLoading && wallet.hasValue) {
        initial = initial.copyWith(
          coins: _fromWallet(wallet.requireValue.coins, CurrencyType.coins),
          gems: _fromWallet(wallet.requireValue.gems, CurrencyType.gems),
        );
      }
    } catch (_) {
      // No wallet in this context (some tests): stay on this phone's count.
    }

    if (saved == null || pending != null) _store.save(initial);
    if (_outbox.isNotEmpty) Future.microtask(_flushOutbox);
    return initial;
  }

  // ---- The account (wallet) -----------------------------------------------

  int _fromWallet(int accountBalance, CurrencyType currency) {
    final waiting = _outbox
        .where((op) => op.currency == currency)
        .fold<int>(0, (sum, op) => sum + op.amount);
    return max(0, accountBalance + waiting);
  }

  void _syncFromWallet(WalletBalance wallet) {
    final coins = _fromWallet(wallet.coins, CurrencyType.coins);
    final gems = _fromWallet(wallet.gems, CurrencyType.gems);
    if (coins == state.coins && gems == state.gems) return;
    _commit(state.copyWith(coins: coins, gems: gems));
  }

  void _loadOutbox() {
    _outbox.clear();
    final raw = _storage?.getString(_outboxKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      for (final item in list) {
        final op = _WalletOp.fromJson(item);
        if (op != null) _outbox.add(op);
      }
    } catch (_) {
      // A damaged queue counts as empty.
    }
  }

  void _saveOutbox() {
    _storage?.setString(
      _outboxKey,
      jsonEncode([for (final op in _outbox) op.toJson()]),
    );
  }

  /// Queues a win (positive) or a spend (negative) for the account. Does
  /// nothing when nobody is signed in: then coins stay on this phone only.
  void _enqueue(CurrencyType currency, int amount, String reason) {
    if (amount == 0 || !_walletLive) return;
    _outbox.add(_WalletOp(currency, amount, reason));
    _saveOutbox();
    Future.microtask(_flushOutbox);
  }

  /// Sends the queue to the account, oldest first. A network or server
  /// problem stops it (it is tried again the next time the balance loads);
  /// a refusal drops that one entry. Afterwards the balance is re-read, so
  /// what is shown is what the account really has.
  Future<void> _flushOutbox() async {
    if (_flushing || _disposed || _outbox.isEmpty || !_walletLive) return;
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    _flushing = true;
    var sentAny = false;
    try {
      final repository = ref.read(walletRepositoryProvider);
      while (_outbox.isNotEmpty && !_disposed) {
        final op = _outbox.first;
        try {
          if (op.amount > 0) {
            await repository.credit(
              userId: user.id,
              currency: op.currency,
              amount: op.amount,
              reason: op.reason,
            );
          } else {
            await repository.debit(
              userId: user.id,
              currency: op.currency,
              amount: -op.amount,
              reason: op.reason,
            );
          }
        } on ValidationException {
          // Refused (for instance not enough funds): drop it; the re-read
          // below puts the true balance on screen.
        } on NotFoundException {
          // Same: nothing to retry.
        } catch (_) {
          break; // offline or a server hiccup: keep it for later
        }
        _outbox.removeAt(0);
        sentAny = true;
        _saveOutbox();
      }
    } finally {
      _flushing = false;
    }
    if (sentAny && !_disposed) ref.invalidate(walletControllerProvider);
  }

  void _commit(RewardsState next) {
    state = next;
    _store.save(next);
  }

  // ---- Spin the Wheel -----------------------------------------------------

  bool canSpinToday() =>
      state.canSpinOn(dateKey(ref.read(rewardsClockProvider)()));

  /// Picks the prize and uses today's spin. Returns the winning index into
  /// [RewardsCatalog.wheel], or null if no spin is available. The wheel must
  /// stop on exactly this segment.
  int? startSpin() {
    final today = dateKey(ref.read(rewardsClockProvider)());
    if (state.pendingSpinReward != null || !state.canSpinOn(today)) return null;
    final index = ref
        .read(rewardsRandomProvider)
        .nextInt(RewardsCatalog.wheel.length);
    final coins = RewardsCatalog.wheel[index].coins;
    _commit(
      state.copyWith(
        lastSpinDate: today,
        lastSpinReward: coins,
        pendingSpinReward: coins,
      ),
    );
    return index;
  }

  /// Credits the pending prize. Returns the coins won, or null if none pending.
  int? completeSpin() {
    final pending = state.pendingSpinReward;
    if (pending == null) return null;
    _commit(
      state.copyWith(coins: state.coins + pending, clearPendingSpin: true),
    );
    _enqueue(CurrencyType.coins, pending, 'spin_wheel');
    return pending;
  }

  // ---- Chest Box ----------------------------------------------------------

  /// Counts one finished game. Safe to call repeatedly with the same
  /// [attemptId]. The cycle earns the Golden chest at 3 games, the Cyber
  /// chest at 6 and the Galaxy chest at 10, then starts again. Earned chests
  /// wait until they are opened; none is ever lost.
  void recordQuizCompleted(String attemptId) {
    if (state.processedQuizIds.contains(attemptId)) return;
    final ids = [...state.processedQuizIds, attemptId];

    var progress = state.chestProgress + 1;
    final earned = <ChestTier>[
      for (final tier in ChestTier.values)
        if (tier.unlockAt == progress) tier,
    ];
    if (progress >= RewardsState.chestCycle) progress = 0;

    final ready = {...state.chestsReady};
    for (final tier in earned) {
      ready[tier] = (ready[tier] ?? 0) + 1;
    }
    _commit(
      state.copyWith(
        processedQuizIds: ids.length > 100
            ? ids.sublist(ids.length - 100)
            : ids,
        chestProgress: progress,
        chestsReady: ready,
      ),
    );
  }

  /// Opens a chest that was earned by playing. The reward is chosen and paid
  /// here, once; an unearned chest pays nothing.
  ChestOpenResult openChest(ChestTier tier) {
    if (!state.chestReady(tier)) {
      return const ChestOpenResult(ChestOpenStatus.notEarned);
    }
    return _open(tier, price: 0);
  }

  /// Opens a chest that was not earned yet by paying [ChestTier.forcePrice]
  /// coins. It does not change game progress and never uses an earned chest.
  ChestOpenResult forceOpenChest(ChestTier tier) {
    if (state.chestReady(tier)) {
      return const ChestOpenResult(ChestOpenStatus.alreadyEarned);
    }
    if (state.coins < tier.forcePrice) {
      return const ChestOpenResult(ChestOpenStatus.notEnoughCoins);
    }
    return _open(tier, price: tier.forcePrice);
  }

  ChestOpenResult _open(ChestTier tier, {required int price}) {
    final random = ref.read(rewardsRandomProvider);
    var coinsWon = 0;
    var gemsWon = 0;
    var next = state.copyWith(coins: state.coins - price);
    if (price == 0) {
      final ready = {...state.chestsReady};
      final left = (ready[tier] ?? 0) - 1;
      if (left > 0) {
        ready[tier] = left;
      } else {
        ready.remove(tier);
      }
      next = next.copyWith(chestsReady: ready);
    }

    final ChestReward reward;
    switch (tier) {
      case ChestTier.golden:
        const min = RewardsCatalog.goldenMinCoins;
        const max = RewardsCatalog.goldenMaxCoins;
        final coins = min + random.nextInt(max - min + 1);
        reward = ChestReward(tier: tier, coins: coins);
        coinsWon = coins;
        next = next.copyWith(coins: next.coins + coins);
      case ChestTier.cyber:
        final unowned = [
          for (final p in [...RewardsCatalog.avatars, ...RewardsCatalog.frames])
            if (!(p.kind == ProductKind.avatar
                ? next.ownedAvatars.contains(p.id)
                : next.ownedFrames.contains(p.id)))
              p,
        ];
        if (unowned.isEmpty) {
          const coins = RewardsCatalog.cyberFallbackCoins;
          reward = ChestReward(tier: tier, coins: coins);
          coinsWon = coins;
          next = next.copyWith(coins: next.coins + coins);
        } else {
          final item = unowned[random.nextInt(unowned.length)];
          reward = ChestReward(tier: tier, cosmetic: item);
          next = item.kind == ProductKind.avatar
              ? next.copyWith(ownedAvatars: {...next.ownedAvatars, item.id})
              : next.copyWith(ownedFrames: {...next.ownedFrames, item.id});
        }
      case ChestTier.galaxy:
        const min = RewardsCatalog.galaxyMinGems;
        const max = RewardsCatalog.galaxyMaxGems;
        final gems = min + random.nextInt(max - min + 1);
        reward = ChestReward(tier: tier, gems: gems);
        gemsWon = gems;
        next = next.copyWith(gems: next.gems + gems);
    }
    _commit(next);
    // The price and the prize go to the account as two entries.
    _enqueue(CurrencyType.coins, -price, 'chest_open_${tier.name}');
    _enqueue(CurrencyType.coins, coinsWon, 'chest_reward_${tier.name}');
    _enqueue(CurrencyType.gems, gemsWon, 'chest_reward_${tier.name}');
    return ChestOpenResult(ChestOpenStatus.opened, reward);
  }

  // ---- Shop ---------------------------------------------------------------

  PurchaseOutcome purchase(String productId) {
    final product = RewardsCatalog.byId(productId);
    if (product == null || product.comingSoon) {
      return PurchaseOutcome.unavailable;
    }
    final owned = switch (product.kind) {
      ProductKind.avatar => state.ownedAvatars.contains(product.id),
      ProductKind.frame => state.ownedFrames.contains(product.id),
      ProductKind.powerUp => false, // consumable: can be bought again
    };
    if (owned) return PurchaseOutcome.alreadyOwned;
    if (state.coins < product.price) return PurchaseOutcome.notEnoughCoins;

    final paid = state.copyWith(coins: state.coins - product.price);
    _commit(switch (product.kind) {
      ProductKind.avatar => paid.copyWith(
        ownedAvatars: {...paid.ownedAvatars, product.id},
      ),
      ProductKind.frame => paid.copyWith(
        ownedFrames: {...paid.ownedFrames, product.id},
      ),
      ProductKind.powerUp => paid.copyWith(
        powerUps: {
          ...paid.powerUps,
          product.powerUp!: paid.powerUpCount(product.powerUp!) + 1,
        },
      ),
    });
    _enqueue(CurrencyType.coins, -product.price, 'shop_${product.id}');
    return PurchaseOutcome.success;
  }

  void equip(String productId) {
    final product = RewardsCatalog.byId(productId);
    if (product == null) return;
    if (product.kind == ProductKind.avatar &&
        state.ownedAvatars.contains(productId)) {
      _commit(state.copyWith(equippedAvatar: productId));
    } else if (product.kind == ProductKind.frame &&
        state.ownedFrames.contains(productId)) {
      _commit(state.copyWith(equippedFrame: productId));
    }
  }

  /// Uses one token. Returns false (and changes nothing) with none left.
  bool consumePowerUp(PowerUpType type) {
    final count = state.powerUpCount(type);
    if (count <= 0) return false;
    final next = {...state.powerUps};
    if (count == 1) {
      next.remove(type);
    } else {
      next[type] = count - 1;
    }
    _commit(state.copyWith(powerUps: next));
    return true;
  }
}

final rewardsProvider = NotifierProvider<RewardsController, RewardsState>(
  RewardsController.new,
);
