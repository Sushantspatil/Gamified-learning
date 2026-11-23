import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/errors/app_exception.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/authentication/domain/entities/app_user.dart';
import 'package:skillverse_app/features/authentication/presentation/providers/auth_providers.dart';
import 'package:skillverse_app/features/monetization/data/monetization_datasource.dart';
import 'package:skillverse_app/features/monetization/data/rewarded_ad_service.dart';
import 'package:skillverse_app/features/monetization/data/store_billing_service.dart';
import 'package:skillverse_app/features/monetization/domain/monetization_models.dart';
import 'package:skillverse_app/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:skillverse_app/features/monetization/presentation/widgets/store_section.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async =>
      const AppUser(id: 'u1', email: 'p@example.com', displayName: 'P');
}

/// Backend stand-in: canned answers, records what was asked.
class _FakeBackend implements MonetizationDatasource {
  List<BillingProduct> catalog = const [
    BillingProduct(
      id: 'gems_110',
      kind: BillingProductKind.consumable,
      title: '110 Gems',
      gems: 110,
    ),
    BillingProduct(
      id: 'quiz_pass',
      kind: BillingProductKind.subscription,
      title: 'Quiz Pass',
    ),
    BillingProduct(
      id: 'pack_gk',
      kind: BillingProductKind.nonConsumable,
      title: 'GK Pack',
      subjects: ['gk'],
    ),
  ];
  Object? verifyOutcome; // a VerifyResult to return, or an exception to throw
  final verified = <String>[];
  AdReward? created;
  Object? createError;
  final List<AdReward> polls = [];
  int devCompletes = 0;
  AdsConfig config = const AdsConfig(
    rewardedAdsEnabled: true,
    androidAdUnitId: 'ca-app-pub-1/2',
    placements: [
      AdPlacement(
        id: 'ad_chest',
        reward: 'chest',
        dailyCap: 3,
        remainingToday: 3,
        available: true,
      ),
    ],
  );

  @override
  Future<List<BillingProduct>> products() async => catalog;
  @override
  Future<String> billingAccountId() async => 'acct-hmac';
  @override
  Future<VerifyResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    verified.add(purchaseToken);
    final o = verifyOutcome;
    if (o is Exception) throw o;
    return (o as VerifyResult?) ??
        VerifyResult(
          status: VerifyStatus.granted,
          productId: productId,
          gemsAdded: 110,
        );
  }

  @override
  Future<Entitlements> entitlements() async => Entitlements.none;
  @override
  Future<int> claimMonthlyGems() async => 60;
  @override
  Future<AdsConfig> adsConfig() async => config;
  @override
  Future<AdReward> createAdReward(String placement) async {
    if (createError != null) throw createError!;
    return created!;
  }

  @override
  Future<AdReward> adReward(String id) async =>
      polls.isEmpty ? created! : polls.removeAt(0);
  @override
  Future<AdReward?> devCompleteAdReward(String id) async {
    devCompletes++;
    return null;
  }

  @override
  Future<PowerUpsStatus> powerUps() async => PowerUpsStatus.empty;
}

class _FakeStore implements StoreBillingService {
  final controller = StreamController<List<StorePurchase>>.broadcast();
  final completed = <String>[];
  final bought = <String>[];
  String? accountUsed;
  bool? consumableUsed;
  int restores = 0;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<StorePurchase>> get purchases => controller.stream;
  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async => [
    if (ids.contains('gems_110'))
      const StoreProduct(
        productId: 'gems_110',
        title: '110 Gems',
        price: '₹49',
        handle: 'g',
      ),
    if (ids.contains('quiz_pass')) ...const [
      StoreProduct(
        productId: 'quiz_pass',
        title: 'Pass',
        price: '₹79',
        basePlanId: 'monthly',
        handle: 'm',
      ),
      StoreProduct(
        productId: 'quiz_pass',
        title: 'Pass',
        price: '₹699',
        basePlanId: 'yearly',
        handle: 'y',
      ),
    ],
    if (ids.contains('pack_gk'))
      const StoreProduct(
        productId: 'pack_gk',
        title: 'GK',
        price: '₹29',
        handle: 'p',
      ),
  ];
  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountId,
    required bool consumable,
  }) async {
    bought.add(product.productId);
    accountUsed = accountId;
    consumableUsed = consumable;
    return true;
  }

  @override
  Future<void> complete(StorePurchase purchase) async =>
      completed.add(purchase.purchaseToken);
  @override
  Future<void> restore({required String accountId}) async => restores++;
}

class _FakeAds implements RewardedAdService {
  RewardedAdOutcome outcome = RewardedAdOutcome.earned;
  int shown = 0;
  String? userId;
  String? customData;
  AdRequestPolicy? policy;

  @override
  Future<RewardedAdOutcome> show({
    required String adUnitId,
    required AdRequestPolicy policy,
    required String ssvUserId,
    required String ssvCustomData,
  }) async {
    shown++;
    userId = ssvUserId;
    customData = ssvCustomData;
    this.policy = policy;
    return outcome;
  }
}

ProviderContainer _container(
  _FakeBackend backend,
  _FakeStore store,
  _FakeAds ads,
) {
  final c = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_SignedIn.new),
      monetizationDatasourceProvider.overrideWithValue(backend),
      storeBillingServiceProvider.overrideWithValue(store),
      rewardedAdServiceProvider.overrideWithValue(ads),
      adRewardPollDelaysProvider.overrideWithValue(const [
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ]),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

StorePurchase _purchase(
  String token, {
  StorePurchaseState state = StorePurchaseState.purchased,
  bool needsCompletion = true,
}) => StorePurchase(
  productId: 'gems_110',
  purchaseToken: token,
  state: state,
  needsCompletion: needsCompletion,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('BillingController', () {
    late _FakeBackend backend;
    late _FakeStore store;
    late ProviderContainer c;

    setUp(() async {
      backend = _FakeBackend();
      store = _FakeStore();
      c = _container(backend, store, _FakeAds());
      await c.read(authControllerProvider.future);
      c.read(
        billingControllerProvider,
      ); // starts itself for the signed-in player
      await _settle();
    });

    test('loads the catalog with Google Play prices and restores on start', () {
      final s = c.read(billingControllerProvider);
      expect(s.available, isTrue);
      expect(s.ofKind(BillingProductKind.consumable).single.id, 'gems_110');
      expect(s.store['quiz_pass']!.map((p) => p.basePlanId), [
        'monthly',
        'yearly',
      ]);
      expect(
        store.restores,
        1,
        reason: 'unfinished purchases are re-checked at launch',
      );
    });

    test(
      'buys with the server account id; gem packs are consumables',
      () async {
        final ctl = c.read(billingControllerProvider.notifier);
        final s = c.read(billingControllerProvider);
        await ctl.buy(s.catalog.first, s.store['gems_110']!.first);
        expect(store.accountUsed, 'acct-hmac');
        expect(store.consumableUsed, isTrue);
        await ctl.buy(s.catalog[2], s.store['pack_gk']!.first);
        expect(
          store.consumableUsed,
          isFalse,
          reason: 'topic packs are kept, not consumed',
        );
      },
    );

    test('finishes a purchase only after the server granted it', () async {
      store.controller.add([_purchase('tok-ok')]);
      await _settle();
      expect(backend.verified, ['tok-ok']);
      expect(store.completed, ['tok-ok']);
      expect(c.read(billingControllerProvider).message, contains('110 gems'));
    });

    test(
      'a rejected purchase is left unfinished so Google refunds it',
      () async {
        backend.verifyOutcome = const ValidationException(
          'purchase could not be verified',
          '400',
        );
        store.controller.add([_purchase('tok-bad')]);
        await _settle();
        expect(store.completed, isEmpty);
      },
    );

    test(
      'an offline verification keeps the purchase for a later retry',
      () async {
        backend.verifyOutcome = const NetworkException('offline');
        store.controller.add([_purchase('tok-net')]);
        await _settle();
        expect(store.completed, isEmpty);
        expect(
          c.read(billingControllerProvider).message,
          contains('added automatically'),
        );
      },
    );

    test(
      'pending payments, cancellations and finished restores are not verified',
      () async {
        store.controller.add([
          _purchase('p1', state: StorePurchaseState.pending),
          _purchase('p2', state: StorePurchaseState.canceled),
          _purchase(
            'p3',
            state: StorePurchaseState.restored,
            needsCompletion: false,
          ),
        ]);
        await _settle();
        expect(backend.verified, isEmpty);
      },
    );

    test('a duplicate event for the same token is verified once', () async {
      store.controller.add([_purchase('dup'), _purchase('dup')]);
      await _settle();
      expect(backend.verified, ['dup']);
    });
  });

  group('AdRewardRunner', () {
    late _FakeBackend backend;
    late _FakeAds ads;
    late ProviderContainer c;

    setUp(() async {
      backend = _FakeBackend();
      ads = _FakeAds();
      c = _container(backend, _FakeStore(), ads);
      await c.read(authControllerProvider.future);
    });

    const pending = AdReward(
      id: 'r1',
      placement: 'ad_chest',
      status: AdRewardStatus.pending,
      adRequired: true,
      ssvUserId: 'ssv-user',
      ssvCustomData: 'r1',
    );
    const paid = AdReward(
      id: 'r1',
      placement: 'ad_chest',
      status: AdRewardStatus.fulfilled,
      adRequired: true,
      rewardCurrency: 'coins',
      rewardAmount: 40,
    );

    test('pays only after the server confirms Google\'s callback', () async {
      backend.created = pending;
      backend.polls.addAll([pending, paid]);
      final r = await c.read(adRewardRunnerProvider).run('ad_chest');
      expect(r.status, AdRunStatus.rewarded);
      expect(r.message, contains('40 coins'));
      expect(ads.userId, 'ssv-user');
      expect(ads.customData, 'r1');
      expect(
        ads.policy!.nonPersonalized,
        isTrue,
        reason: 'unverified age gets non-personalised ads',
      );
    });

    test('Quiz Pass rewards arrive without an ad', () async {
      backend.created = const AdReward(
        id: 'r2',
        placement: 'ad_chest',
        status: AdRewardStatus.fulfilled,
        adRequired: false,
        rewardCurrency: 'gems',
        rewardAmount: 3,
      );
      final r = await c.read(adRewardRunnerProvider).run('ad_chest');
      expect(r.status, AdRunStatus.rewarded);
      expect(ads.shown, 0);
    });

    test('closing the ad early gives nothing and does not poll', () async {
      backend.created = pending;
      ads.outcome = RewardedAdOutcome.dismissed;
      final r = await c.read(adRewardRunnerProvider).run('ad_chest');
      expect(r.status, AdRunStatus.cancelled);
      expect(backend.devCompletes, 0);
    });

    test('daily caps come back as a friendly limit', () async {
      backend.createError = const ValidationException(
        'come back tomorrow',
        '429',
      );
      final r = await c.read(adRewardRunnerProvider).run('ad_chest');
      expect(r.status, AdRunStatus.limited);
      expect(ads.shown, 0);
    });

    test('a slow callback reports the reward as on its way', () async {
      backend.created = pending;
      final r = await c.read(adRewardRunnerProvider).run('ad_chest');
      expect(r.status, AdRunStatus.pending);
    });
  });

  group('MonetizationRemoteDatasource', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<(MonetizationRemoteDatasource, List<http.Request>)> withServer(
      Map<String, (int, Object)> routes,
    ) async {
      final storage = await LocalStorageService.create();
      final seen = <http.Request>[];
      final api = ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          seen.add(request);
          final r = routes[request.url.path.replaceFirst('/api/v1', '')];
          if (r == null) return http.Response('{"success":false}', 404);
          return http.Response(
            jsonEncode({'success': r.$1 < 300, 'message': 'm', 'data': r.$2}),
            r.$1,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      return (MonetizationRemoteDatasource(apiClient: api), seen);
    }

    test(
      'parses products, a pending verify, ads config and power-ups',
      () async {
        final (ds, seen) = await withServer({
          '/billing/products': (
            200,
            [
              {
                'product_id': 'pack_gk',
                'kind': 'non_consumable',
                'title': 'GK',
                'subjects': ['gk_a', 'gk_b'],
                'owned': true,
              },
            ],
          ),
          '/billing/verify': (
            202,
            {'status': 'pending', 'product_id': 'gems_20'},
          ),
          '/ads/config': (
            200,
            {
              'rewarded_ads_enabled': true,
              'rewarded_ad_unit_ids': {'android': 'ca-app-pub-x/1', 'ios': ''},
              'policy': {
                'non_personalized': true,
                'max_ad_content_rating': 'G',
                'age_treatment': 'teen',
              },
              'placements': [
                {
                  'id': 'skip',
                  'reward': 'skip',
                  'daily_cap': 2,
                  'remaining_today': 0,
                  'available': false,
                  'reason': 'daily_limit',
                },
              ],
            },
          ),
          '/power-ups': (
            200,
            {
              'max_tokens': 5,
              'power_ups': [
                {'id': 'fifty_fifty', 'price_coins': 20, 'tokens': 2},
              ],
            },
          ),
        });
        final products = await ds.products();
        expect(products.single.kind, BillingProductKind.nonConsumable);
        expect(products.single.subjects, ['gk_a', 'gk_b']);
        expect(products.single.owned, isTrue);

        final v = await ds.verifyPurchase(
          productId: 'gems_20',
          purchaseToken: 'tok',
        );
        expect(v.status, VerifyStatus.pending);
        expect(jsonDecode(seen.last.body), {
          'product_id': 'gems_20',
          'purchase_token': 'tok',
        });

        final cfg = await ds.adsConfig();
        expect(cfg.androidAdUnitId, 'ca-app-pub-x/1');
        expect(cfg.iosAdUnitId, isNull);
        expect(cfg.placement('skip')!.reason, 'daily_limit');

        final pu = await ds.powerUps();
        expect(pu.tokens('fifty_fifty'), 2);
        expect(pu.powerUps['fifty_fifty']!.priceCoins, 20);
      },
    );

    test('a missing ad policy falls back to the most protective settings', () {
      final p = AdRequestPolicy.fromJson(const {});
      expect(p.nonPersonalized, isTrue);
      expect(p.maxAdContentRating, 'G');
      expect(p.ageTreatment, 'teen');
    });
  });

  group('QuizRemoteDatasource.useFiftyFifty', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sends the session and surfaces "cannot pay" as code 402', () async {
      final storage = await LocalStorageService.create();
      var status = 200;
      Map<String, dynamic>? body;
      final api = ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test/api/v1'),
        storage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/quiz/sessions/create')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'session': 's-1', 'questions': []},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              status == 200
                  ? {
                      'success': true,
                      'data': {
                        'question': 'q1',
                        'hidden_options': ['a', 'c'],
                        'paid_with': 'coins',
                        'cost': 20,
                      },
                    }
                  : {
                      'success': false,
                      'message': 'not enough coins for this power-up',
                    },
            ),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final ds = QuizRemoteDatasource(apiClient: api);
      // No game yet: nothing is sent and nothing is charged.
      await expectLater(
        ds.useFiftyFifty('q1'),
        throwsA(isA<ServerException>()),
      );
      expect(body, isNull);
      await ds.createSession(topicId: 'accounts');
      expect(ds.activeSessionId, 's-1');
      expect(await ds.useFiftyFifty('q1'), ['a', 'c']);
      expect(body, {'session': 's-1', 'question': 'q1'});
      status = 402;
      await expectLater(
        ds.useFiftyFifty('q1'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', '402')),
      );
    });
  });

  testWidgets(
    'Store tab shows Play prices and buys with the server account id',
    (tester) async {
      final backend = _FakeBackend();
      final store = _FakeStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_SignedIn.new),
            monetizationDatasourceProvider.overrideWithValue(backend),
            storeBillingServiceProvider.overrideWithValue(store),
            rewardedAdServiceProvider.overrideWithValue(_FakeAds()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: StoreSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('110 Gems'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
      expect(find.text('Monthly · ₹79'), findsOneWidget);
      expect(find.text('Yearly · ₹699'), findsOneWidget);
      expect(
        find.text('Watch ad'),
        findsOneWidget,
        reason: 'the ad chest is offered, only on tap',
      );
      await tester.tap(find.text('₹49'));
      await tester.pumpAndSettle();
      expect(store.bought, ['gems_110']);
      expect(store.accountUsed, 'acct-hmac');
    },
  );
}
