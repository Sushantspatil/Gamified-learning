import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/monetization_datasource.dart';
import '../../data/rewarded_ad_service.dart';
import '../../data/store_billing_service.dart';
import '../../domain/monetization_models.dart';

// ---- Bindings (tests override these) ------------------------------------------

final monetizationDatasourceProvider = Provider<MonetizationDatasource>((ref) {
  return MonetizationRemoteDatasource(apiClient: ref.watch(apiClientProvider));
});

/// Google Play Billing on Android; elsewhere purchases are not offered (the
/// backend verifies Google Play purchases only).
final storeBillingServiceProvider = Provider<StoreBillingService>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const UnavailableStoreBillingService();
  }
  return PlayStoreBillingService();
});

final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return const UnavailableRewardedAdService();
  }
  return GoogleRewardedAdService();
});

/// Seconds between polls for Google's reward callback (tests use zeros).
final adRewardPollDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 1),
    Duration(seconds: 1),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 3),
    Duration(seconds: 4),
  ],
);

// ---- Server state ----------------------------------------------------------------

bool _signedIn(Ref ref) =>
    ref.watch(authControllerProvider).valueOrNull != null;

final entitlementsProvider = FutureProvider.autoDispose<Entitlements>((
  ref,
) async {
  if (!_signedIn(ref)) return Entitlements.none;
  return ref.watch(monetizationDatasourceProvider).entitlements();
});

final adsConfigProvider = FutureProvider.autoDispose<AdsConfig>((ref) async {
  if (!_signedIn(ref)) return AdsConfig.off;
  return ref.watch(monetizationDatasourceProvider).adsConfig();
});

final powerUpsStatusProvider = FutureProvider.autoDispose<PowerUpsStatus>((
  ref,
) async {
  if (!_signedIn(ref)) return PowerUpsStatus.empty;
  return ref.watch(monetizationDatasourceProvider).powerUps();
});

/// True when the player's region requires an "ad privacy choices" entry
/// point (Google UMP, e.g. EEA/UK).
final adPrivacyOptionsRequiredProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final config = await ref.watch(adsConfigProvider.future);
  if (!config.rewardedAdsEnabled) return false;
  return ref
      .watch(rewardedAdServiceProvider)
      .privacyOptionsRequired(config.policy);
});

/// Re-reads every balance and entitlement after the server changed them.
void refreshMonetization(Ref ref) {
  ref.invalidate(
    walletControllerProvider,
  ); // the rewards screens follow the wallet
  ref.invalidate(entitlementsProvider);
  ref.invalidate(adsConfigProvider);
  ref.invalidate(powerUpsStatusProvider);
}

// ---- Google Play Billing ---------------------------------------------------------

@immutable
class BillingState {
  final bool loading;
  final bool available;
  final List<BillingProduct> catalog;

  /// Google Play's view of each product (price), by product id. A
  /// subscription has one entry per base plan.
  final Map<String, List<StoreProduct>> store;
  final String? busyProductId;
  final String? message;

  /// Increments with every new [message], so the UI shows each one once.
  final int messageSeq;

  const BillingState({
    this.loading = true,
    this.available = false,
    this.catalog = const [],
    this.store = const {},
    this.busyProductId,
    this.message,
    this.messageSeq = 0,
  });

  List<BillingProduct> ofKind(BillingProductKind kind) => [
    for (final p in catalog)
      if (p.kind == kind && (store[p.id]?.isNotEmpty ?? false)) p,
  ];

  BillingState copyWith({
    bool? loading,
    bool? available,
    List<BillingProduct>? catalog,
    Map<String, List<StoreProduct>>? store,
    String? busyProductId,
    bool clearBusy = false,
    String? message,
  }) => BillingState(
    loading: loading ?? this.loading,
    available: available ?? this.available,
    catalog: catalog ?? this.catalog,
    store: store ?? this.store,
    busyProductId: clearBusy ? null : busyProductId ?? this.busyProductId,
    message: message ?? this.message,
    messageSeq: message != null ? messageSeq + 1 : messageSeq,
  );
}

/// Buys through Google Play and lets the server verify and grant. The app
/// never grants anything itself: it forwards the purchase token, finishes the
/// purchase only after the server accepted it, and leaves a rejected one
/// unfinished (Google refunds unfinished purchases after three days).
///
/// Purchases interrupted by a crash or lost connection are retried: Google
/// re-reports unfinished purchases, and [start] asks for them on launch.
class BillingController extends Notifier<BillingState> {
  StreamSubscription<List<StorePurchase>>? _sub;
  String? _accountId;
  bool _started = false;
  final Set<String> _inFlight = {};

  /// Tokens the server accepted during this run: a repeated event for one of
  /// them is not sent again.
  final Set<String> _done = {};

  /// Bumped when the signed-in player changes (or on dispose): work started
  /// for the previous player never touches the new player's state.
  int _generation = 0;

  MonetizationDatasource get _ds => ref.read(monetizationDatasourceProvider);
  StoreBillingService get _storeService =>
      ref.read(storeBillingServiceProvider);

  void _reset() {
    _generation++;
    _accountId = null;
    _started = false;
    _done.clear();
    _inFlight.clear();
    _sub?.cancel();
    _sub = null;
  }

  @override
  BillingState build() {
    ref.onDispose(_reset);
    // A different player must never reuse the previous player's account id,
    // listener or memory of finished purchases.
    ref.listen<String?>(
      authControllerProvider.select((s) => s.valueOrNull?.id),
      (previous, next) {
        if (previous == next) return;
        _reset();
        state = BillingState(loading: next != null);
        if (next != null) Future.microtask(start);
      },
    );
    _reset();
    final auth = ref.read(authControllerProvider);
    final userId = auth.valueOrNull?.id;
    if (userId != null) Future.microtask(start);
    return BillingState(loading: auth.isLoading || userId != null);
  }

  /// Connects to Google Play once per player, loads the catalog and re-checks
  /// unfinished purchases. Safe to call repeatedly.
  Future<void> start() async {
    if (_started || ref.read(authControllerProvider).valueOrNull == null) {
      return;
    }
    _started = true;
    final gen = _generation;
    final store = _storeService;
    final available = await store.isAvailable();
    if (gen != _generation) return;
    if (!available) {
      state = state.copyWith(loading: false, available: false);
      return;
    }
    _sub = store.purchases.listen((list) async {
      for (final p in list) {
        await _handle(p, gen);
      }
    }, onError: (_) {});
    await refresh();
    if (gen != _generation || !state.available) return;
    try {
      await store.restore(accountId: await _account());
    } catch (_) {
      // Offline: tried again on the next launch.
    }
  }

  Future<String> _account() async =>
      _accountId ??= await _ds.billingAccountId();

  /// Reloads the catalog (and owned flags) and Google Play's prices.
  Future<void> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (auth.valueOrNull == null) {
      if (!auth.isLoading) {
        state = state.copyWith(loading: false, available: false);
      }
      return; // still signing in: started once the player is known
    }
    final gen = _generation;
    final ds = _ds;
    final store = _storeService;
    try {
      final catalog = await ds.products();
      final details = await store.queryProducts({
        for (final p in catalog) p.id,
      });
      if (gen != _generation) return;
      final byId = <String, List<StoreProduct>>{};
      for (final d in details) {
        (byId[d.productId] ??= []).add(d);
      }
      state = state.copyWith(
        loading: false,
        available: true,
        catalog: catalog,
        store: byId,
      );
    } catch (_) {
      if (gen == _generation) {
        state = state.copyWith(loading: false, available: false);
      }
    }
  }

  Future<void> buy(BillingProduct product, StoreProduct storeProduct) async {
    if (state.busyProductId != null) return; // one purchase at a time
    final gen = _generation;
    state = state.copyWith(busyProductId: product.id);
    try {
      final launched = await _storeService.buy(
        storeProduct,
        accountId: await _account(),
        consumable: product.kind == BillingProductKind.consumable,
      );
      if (!launched) {
        _say(
          'Google Play could not start the purchase. Please try again.',
          gen,
        );
      }
    } on AppException catch (e) {
      _say(e.message, gen);
    } catch (_) {
      _say('Google Play could not start the purchase. Please try again.', gen);
    } finally {
      if (gen == _generation) state = state.copyWith(clearBusy: true);
    }
  }

  Future<void> restore() async {
    final gen = _generation;
    try {
      await _storeService.restore(accountId: await _account());
      _say('Checking your purchases with Google Play…', gen);
    } catch (_) {
      _say('Could not reach Google Play. Please try again.', gen);
    }
  }

  Future<void> _handle(StorePurchase p, int gen) async {
    switch (p.state) {
      case StorePurchaseState.pending:
        _say(
          'Payment pending. It will be added as soon as Google confirms it.',
          gen,
        );
        return;
      case StorePurchaseState.canceled:
        return;
      case StorePurchaseState.error:
        _say(p.errorMessage ?? 'The purchase did not go through.', gen);
        return;
      case StorePurchaseState.restored when !p.needsCompletion:
        return; // finished earlier, so the server already granted it
      case StorePurchaseState.purchased:
      case StorePurchaseState.restored:
        break;
    }
    if (p.purchaseToken.isEmpty ||
        _done.contains(p.purchaseToken) ||
        !_inFlight.add(p.purchaseToken)) {
      return;
    }
    final ds = _ds;
    final store = _storeService;
    try {
      final result = await ds.verifyPurchase(
        productId: p.productId,
        purchaseToken: p.purchaseToken,
      );
      if (result.status == VerifyStatus.pending) {
        _say(
          'Payment pending. It will be added as soon as Google confirms it.',
          gen,
        );
        return;
      }
      _done.add(p.purchaseToken);
      await store.complete(p); // granted on the server: finish it with Google
      if (gen != _generation) return;
      refreshMonetization(ref);
      await refresh();
      if (result.status == VerifyStatus.granted) _say(_thanks(result), gen);
    } on ValidationException catch (e) {
      _say(e.message, gen); // rejected: left unfinished so Google refunds it
    } on AuthException catch (e) {
      _say(
        e.code == 'forbidden'
            ? e.message
            : 'Please sign in to finish your purchase.',
        gen,
      );
    } catch (_) {
      // Offline or the server is busy: Google re-reports it and we retry.
      _say(
        'We could not confirm your purchase yet. It will be added automatically.',
        gen,
      );
    } finally {
      _inFlight.remove(p.purchaseToken);
    }
  }

  String _thanks(VerifyResult r) {
    if (r.gemsAdded > 0 || r.coinsAdded > 0) {
      final parts = [
        if (r.gemsAdded > 0) '${r.gemsAdded} gems',
        if (r.coinsAdded > 0) '${r.coinsAdded} coins',
      ];
      return 'Thank you! ${parts.join(' and ')} added.';
    }
    if (r.isPremium) return 'Welcome to the Quiz Pass!';
    if (r.unlockedSubjects.isNotEmpty) return 'Topic pack unlocked. Enjoy!';
    return 'Purchase complete. Thank you!';
  }

  /// Claims the Quiz Pass monthly gems (the server allows once a month).
  Future<void> claimMonthlyGems() async {
    final gen = _generation;
    try {
      final gems = await _ds.claimMonthlyGems();
      if (gen != _generation) return;
      refreshMonetization(ref);
      _say('$gems gems added. See you next month!', gen);
    } on AppException catch (e) {
      _say(e.message, gen);
    } catch (_) {
      _say('Could not claim right now. Please try again.', gen);
    }
  }

  void _say(String message, int gen) {
    if (gen == _generation) state = state.copyWith(message: message);
  }
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);

// ---- Rewarded ads ------------------------------------------------------------------

enum AdRunStatus { rewarded, pending, cancelled, unavailable, limited, failed }

@immutable
class AdRunResult {
  final AdRunStatus status;
  final AdReward? reward;
  final String message;

  const AdRunResult(this.status, this.message, [this.reward]);
}

/// Runs one rewarded ad the player asked for: the server checks the caps and
/// issues a request id, the ad is shown with that id for Google's signed
/// callback, then the app waits for the server to confirm the payout. Quiz
/// Pass holders get the reward straight away, without an ad.
class AdRewardRunner {
  final Ref _ref;
  bool _running = false;

  AdRewardRunner(this._ref);

  Future<AdRunResult> run(String placement) async {
    if (_running) {
      return const AdRunResult(AdRunStatus.cancelled, 'One moment…');
    }
    _running = true;
    final ds = _ref.read(monetizationDatasourceProvider);
    try {
      final AdReward reward;
      try {
        reward = await ds.createAdReward(placement);
      } on ValidationException catch (e) {
        return AdRunResult(
          AdRunStatus.limited,
          e.message,
        ); // caps, cooldown, token limit
      } on ServerException catch (e) {
        if (e.code == '503') {
          return const AdRunResult(
            AdRunStatus.unavailable,
            'Rewards are not available right now.',
          );
        }
        rethrow;
      }
      if (reward.isFulfilled) {
        refreshMonetization(_ref);
        return AdRunResult(
          AdRunStatus.rewarded,
          'You got ${rewardLabel(reward.rewardCurrency, reward.rewardAmount)}!',
          reward,
        );
      }

      final config = await ds.adsConfig();
      final unit = defaultTargetPlatform == TargetPlatform.iOS
          ? config.iosAdUnitId
          : config.androidAdUnitId;
      final userId = reward.ssvUserId;
      if (!config.rewardedAdsEnabled || unit == null || userId == null) {
        return const AdRunResult(
          AdRunStatus.unavailable,
          'No ad is available right now. Please try later.',
        );
      }
      final outcome = await _ref
          .read(rewardedAdServiceProvider)
          .show(
            adUnitId: unit,
            policy: config.policy,
            ssvUserId: userId,
            ssvCustomData: reward.ssvCustomData ?? reward.id,
          );
      switch (outcome) {
        case RewardedAdOutcome.dismissed:
          return const AdRunResult(
            AdRunStatus.cancelled,
            'The ad was closed early, so no reward this time.',
          );
        case RewardedAdOutcome.unavailable:
          return const AdRunResult(
            AdRunStatus.unavailable,
            'No ad is available right now. Please try later.',
          );
        case RewardedAdOutcome.earned:
          break;
      }

      final paid = await _waitForPayout(ds, reward.id);
      refreshMonetization(_ref);
      if (paid != null) {
        return AdRunResult(
          AdRunStatus.rewarded,
          'You got ${rewardLabel(paid.rewardCurrency, paid.rewardAmount)}!',
          paid,
        );
      }
      return const AdRunResult(
        AdRunStatus.pending,
        'Thanks for watching! Your reward will arrive in a moment.',
      );
    } catch (_) {
      return const AdRunResult(
        AdRunStatus.failed,
        'Something went wrong. Please try again.',
      );
    } finally {
      _running = false;
    }
  }

  /// Google's callback usually reaches the server within seconds.
  Future<AdReward?> _waitForPayout(MonetizationDatasource ds, String id) async {
    for (final delay in _ref.read(adRewardPollDelaysProvider)) {
      await Future<void>.delayed(delay);
      try {
        final r = await ds.adReward(id);
        if (r.isFulfilled) return r;
        if (r.status == AdRewardStatus.expired) return null;
      } catch (_) {
        // keep waiting; the reward is paid on the server regardless
      }
    }
    if (kDebugMode) {
      // Local testing with Google's test ads (no callback): the server
      // completes it only when ADS_DEV_AUTO_FULFILL is on, never in production.
      final r = await ds.devCompleteAdReward(id);
      if (r != null && r.isFulfilled) return r;
    }
    return null;
  }
}

final adRewardRunnerProvider = Provider<AdRewardRunner>(
  (ref) => AdRewardRunner(ref),
);

/// Starts Google Play Billing once a player is signed in, so purchases that
/// were interrupted (crash, lost connection) are verified and finished on the
/// next launch. Called from main(), never from widget tests.
void startBillingWhenSignedIn(ProviderContainer container) {
  container.listen(authControllerProvider.select((s) => s.valueOrNull?.id), (
    previous,
    next,
  ) {
    if (next != null) {
      container.read(billingControllerProvider.notifier).start();
    }
  }, fireImmediately: true);
}
