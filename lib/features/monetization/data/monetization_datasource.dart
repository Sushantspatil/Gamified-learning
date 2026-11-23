import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/monetization_models.dart';

/// Backend calls for payments, rewarded ads and server-charged power-ups.
/// Every grant happens on the server; these calls only ask and report.
abstract class MonetizationDatasource {
  Future<List<BillingProduct>> products();
  Future<String> billingAccountId();
  Future<VerifyResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
  });
  Future<Entitlements> entitlements();
  Future<int> claimMonthlyGems();
  Future<AdsConfig> adsConfig();
  Future<AdReward> createAdReward(String placement);
  Future<AdReward> adReward(String id);

  /// Local testing only (the server refuses it unless explicitly enabled).
  Future<AdReward?> devCompleteAdReward(String id);
  Future<PowerUpsStatus> powerUps();
}

class MonetizationRemoteDatasource implements MonetizationDatasource {
  final ApiClient _api;

  MonetizationRemoteDatasource({required ApiClient apiClient})
    : _api = apiClient;

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ServerException('Unexpected response from the server');
  }

  @override
  Future<List<BillingProduct>> products() async {
    final data = await _api.get(ApiEndpoints.billingProducts);
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) BillingProduct.fromJson(item),
    ];
  }

  @override
  Future<String> billingAccountId() async {
    final data = _map(await _api.get(ApiEndpoints.billingAccountId));
    final id = data['obfuscated_account_id'];
    if (id is! String || id.isEmpty) {
      throw const ServerException('Payments are not available right now');
    }
    return id;
  }

  @override
  Future<VerifyResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    final data = await _api.post(
      ApiEndpoints.billingVerify,
      body: {'product_id': productId, 'purchase_token': purchaseToken},
    );
    return VerifyResult.fromJson(_map(data));
  }

  @override
  Future<Entitlements> entitlements() async => Entitlements.fromJson(
    _map(await _api.get(ApiEndpoints.billingEntitlements)),
  );

  @override
  Future<int> claimMonthlyGems() async {
    final data = _map(await _api.post(ApiEndpoints.passMonthlyGems, body: {}));
    return (data['gems_added'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<AdsConfig> adsConfig() async =>
      AdsConfig.fromJson(_map(await _api.get(ApiEndpoints.adsConfig)));

  @override
  Future<AdReward> createAdReward(String placement) async => AdReward.fromJson(
    _map(
      await _api.post(ApiEndpoints.adsRewards, body: {'placement': placement}),
    ),
  );

  @override
  Future<AdReward> adReward(String id) async =>
      AdReward.fromJson(_map(await _api.get(ApiEndpoints.adsReward(id))));

  @override
  Future<AdReward?> devCompleteAdReward(String id) async {
    try {
      return AdReward.fromJson(
        _map(await _api.post(ApiEndpoints.adsRewardDevComplete(id), body: {})),
      );
    } on NotFoundException {
      return null; // not enabled on this server (always the case in production)
    }
  }

  @override
  Future<PowerUpsStatus> powerUps() async =>
      PowerUpsStatus.fromJson(_map(await _api.get(ApiEndpoints.powerUps)));
}
