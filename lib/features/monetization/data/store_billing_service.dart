import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// A product as Google Play shows it, with the localised price. A
/// subscription appears once per base plan (monthly, yearly).
@immutable
class StoreProduct {
  final String productId;
  final String title;
  final String price;
  final String? basePlanId;

  /// The plugin's own object, passed back when buying.
  final Object handle;

  const StoreProduct({
    required this.productId,
    required this.title,
    required this.price,
    required this.handle,
    this.basePlanId,
  });
}

enum StorePurchaseState { pending, purchased, restored, error, canceled }

/// A purchase reported by Google Play. Only the backend decides whether it
/// is real and what it gives; the app forwards [purchaseToken] to it.
@immutable
class StorePurchase {
  final String productId;
  final String purchaseToken;
  final StorePurchaseState state;
  final bool needsCompletion;
  final String? errorMessage;
  final Object? handle;

  const StorePurchase({
    required this.productId,
    required this.purchaseToken,
    required this.state,
    this.needsCompletion = false,
    this.errorMessage,
    this.handle,
  });
}

/// Google Play Billing, behind an interface so tests (and platforms without
/// Play, such as iOS, web and desktop for now) use a stand-in.
abstract class StoreBillingService {
  Future<bool> isAvailable();
  Stream<List<StorePurchase>> get purchases;
  Future<List<StoreProduct>> queryProducts(Set<String> ids);

  /// Opens Google Play's purchase sheet. [accountId] is the server-issued
  /// obfuscated account id, so the purchase can only be redeemed by this
  /// player. Consumables are consumed by the server after it verifies them.
  Future<bool> buy(
    StoreProduct product, {
    required String accountId,
    required bool consumable,
  });

  /// Finishes a purchase the server accepted (acknowledges it on Android).
  Future<void> complete(StorePurchase purchase);

  /// Asks Play to report owned and unfinished purchases again.
  Future<void> restore({required String accountId});
}

/// Used where Google Play is not available.
class UnavailableStoreBillingService implements StoreBillingService {
  const UnavailableStoreBillingService();

  @override
  Future<bool> isAvailable() async => false;
  @override
  Stream<List<StorePurchase>> get purchases => const Stream.empty();
  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async => const [];
  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountId,
    required bool consumable,
  }) async => false;
  @override
  Future<void> complete(StorePurchase purchase) async {}
  @override
  Future<void> restore({required String accountId}) async {}
}

class PlayStoreBillingService implements StoreBillingService {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<List<StorePurchase>> get purchases =>
      _iap.purchaseStream.map((list) => [for (final p in list) _toStore(p)]);

  StorePurchase _toStore(PurchaseDetails p) => StorePurchase(
    productId: p.productID,
    purchaseToken: p.verificationData.serverVerificationData,
    state: switch (p.status) {
      PurchaseStatus.pending => StorePurchaseState.pending,
      PurchaseStatus.purchased => StorePurchaseState.purchased,
      PurchaseStatus.restored => StorePurchaseState.restored,
      PurchaseStatus.canceled => StorePurchaseState.canceled,
      PurchaseStatus.error => StorePurchaseState.error,
    },
    needsCompletion: p.pendingCompletePurchase,
    errorMessage: p.error?.message,
    handle: p,
  );

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _iap.queryProductDetails(ids);
    final out = <StoreProduct>[];
    for (final d in res.productDetails) {
      String? basePlan;
      if (d is GooglePlayProductDetails && d.subscriptionIndex != null) {
        final offer =
            d.productDetails.subscriptionOfferDetails![d.subscriptionIndex!];
        // Base plans only (offers with an offerId are promotions/trials).
        if (offer.offerId != null) continue;
        basePlan = offer.basePlanId;
      }
      out.add(
        StoreProduct(
          productId: d.id,
          title: d.title,
          price: d.price,
          basePlanId: basePlan,
          handle: d,
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> buy(
    StoreProduct product, {
    required String accountId,
    required bool consumable,
  }) {
    final param = GooglePlayPurchaseParam(
      productDetails: product.handle as ProductDetails,
      applicationUserName: accountId, // becomes obfuscatedAccountId
    );
    return consumable
        // autoConsume: false — the server consumes after verifying, so a
        // purchase is never used up before it was credited.
        ? _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    final handle = purchase.handle;
    if (handle is! PurchaseDetails || !handle.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(handle);
    } catch (_) {
      // The server already consumed or acknowledged it; nothing to do.
    }
  }

  @override
  Future<void> restore({required String accountId}) =>
      _iap.restorePurchases(applicationUserName: accountId);
}
