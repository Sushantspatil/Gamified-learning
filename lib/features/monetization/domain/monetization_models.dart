import 'package:flutter/foundation.dart';

/// What Google Play sells. Mirrors the backend `billing_products.kind`.
enum BillingProductKind {
  consumable, // gem packs
  subscription, // the Quiz Pass
  nonConsumable; // topic packs

  static BillingProductKind fromApi(String value) => switch (value) {
    'subscription' => BillingProductKind.subscription,
    'non_consumable' => BillingProductKind.nonConsumable,
    _ => BillingProductKind.consumable,
  };
}

/// A product from the backend catalog (prices come from Google Play only).
@immutable
class BillingProduct {
  final String id;
  final BillingProductKind kind;
  final String title;
  final int coins;
  final int gems;
  final List<String> subjects;
  final bool owned;

  const BillingProduct({
    required this.id,
    required this.kind,
    required this.title,
    this.coins = 0,
    this.gems = 0,
    this.subjects = const [],
    this.owned = false,
  });

  factory BillingProduct.fromJson(Map<String, dynamic> json) => BillingProduct(
    id: json['product_id'] as String? ?? '',
    kind: BillingProductKind.fromApi(json['kind'] as String? ?? ''),
    title: json['title'] as String? ?? '',
    coins: (json['coins'] as num?)?.toInt() ?? 0,
    gems: (json['gems'] as num?)?.toInt() ?? 0,
    subjects: _strings(json['subjects']),
    owned: json['owned'] as bool? ?? false,
  );
}

/// Result of `POST /billing/verify`.
enum VerifyStatus { granted, alreadyGranted, pending }

@immutable
class VerifyResult {
  final VerifyStatus status;
  final String productId;
  final int coinsAdded;
  final int gemsAdded;
  final bool isPremium;
  final List<String> unlockedSubjects;

  const VerifyResult({
    required this.status,
    required this.productId,
    this.coinsAdded = 0,
    this.gemsAdded = 0,
    this.isPremium = false,
    this.unlockedSubjects = const [],
  });

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    return VerifyResult(
      status: switch (json['status']) {
        'pending' => VerifyStatus.pending,
        'already_granted' => VerifyStatus.alreadyGranted,
        _ => VerifyStatus.granted,
      },
      productId: json['product_id'] as String? ?? '',
      coinsAdded: (json['coins_added'] as num?)?.toInt() ?? 0,
      gemsAdded: (json['gems_added'] as num?)?.toInt() ?? 0,
      isPremium: sub is Map && sub['is_premium'] == true,
      unlockedSubjects: _strings(json['unlocked_subjects']),
    );
  }
}

/// What the player has paid for, computed on the server.
@immutable
class Entitlements {
  final bool isPremium;
  final DateTime? passExpiresAt;
  final bool passAutoRenewing;
  final List<String> topicPacks;
  final int monthlyGems;
  final bool monthlyGemsClaimed;
  final int extraFreezeSlots;

  const Entitlements({
    this.isPremium = false,
    this.passExpiresAt,
    this.passAutoRenewing = false,
    this.topicPacks = const [],
    this.monthlyGems = 0,
    this.monthlyGemsClaimed = false,
    this.extraFreezeSlots = 0,
  });

  static const none = Entitlements();

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] is Map<String, dynamic>
        ? json['subscription'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final perks = json['perks'] is Map<String, dynamic>
        ? json['perks'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final packs = json['topic_packs'];
    return Entitlements(
      isPremium: sub['is_premium'] == true,
      passExpiresAt: DateTime.tryParse(sub['expires_at'] as String? ?? ''),
      passAutoRenewing: sub['auto_renewing'] == true,
      topicPacks: packs is List
          ? [
              for (final p in packs)
                if (p is Map && p['product_id'] is String)
                  p['product_id'] as String,
            ]
          : const [],
      monthlyGems: (perks['monthly_gems'] as num?)?.toInt() ?? 0,
      monthlyGemsClaimed: perks['monthly_gems_claimed'] == true,
      extraFreezeSlots:
          (perks['extra_streak_freeze_slots'] as num?)?.toInt() ?? 0,
    );
  }
}

/// How ads must be requested for this player. Decided by the server: until
/// age is verified everyone gets under-18 treatment (non-personalised ads,
/// G rating).
@immutable
class AdRequestPolicy {
  final bool nonPersonalized;
  final String maxAdContentRating;
  final String ageTreatment; // teen, child or unspecified

  const AdRequestPolicy({
    this.nonPersonalized = true,
    this.maxAdContentRating = 'G',
    this.ageTreatment = 'teen',
  });

  factory AdRequestPolicy.fromJson(Map<String, dynamic> json) =>
      AdRequestPolicy(
        // Anything missing falls back to the most protective setting.
        nonPersonalized: json['non_personalized'] as bool? ?? true,
        maxAdContentRating: json['max_ad_content_rating'] as String? ?? 'G',
        ageTreatment: json['age_treatment'] as String? ?? 'teen',
      );
}

/// Reward placements offered for a rewarded ad.
abstract final class AdPlacements {
  static const adChest = 'ad_chest';
  static const fiftyFifty = 'fifty_fifty';
  static const addTime = 'add_time';
  static const skip = 'skip';
}

@immutable
class AdPlacement {
  final String id;
  final String reward; // 'chest' or a power-up token id
  final int dailyCap;
  final int remainingToday;
  final bool available;
  final String? reason; // ads_unavailable, daily_limit, token_limit

  const AdPlacement({
    required this.id,
    required this.reward,
    required this.dailyCap,
    required this.remainingToday,
    required this.available,
    this.reason,
  });

  factory AdPlacement.fromJson(Map<String, dynamic> json) => AdPlacement(
    id: json['id'] as String? ?? '',
    reward: json['reward'] as String? ?? '',
    dailyCap: (json['daily_cap'] as num?)?.toInt() ?? 0,
    remainingToday: (json['remaining_today'] as num?)?.toInt() ?? 0,
    available: json['available'] as bool? ?? false,
    reason: json['reason'] as String?,
  );
}

@immutable
class AdsConfig {
  final bool rewardedAdsEnabled;
  final bool adFree; // Quiz Pass: rewards without watching ads
  final String? androidAdUnitId;
  final String? iosAdUnitId;
  final AdRequestPolicy policy;
  final List<AdPlacement> placements;
  final int remainingToday;

  const AdsConfig({
    this.rewardedAdsEnabled = false,
    this.adFree = false,
    this.androidAdUnitId,
    this.iosAdUnitId,
    this.policy = const AdRequestPolicy(),
    this.placements = const [],
    this.remainingToday = 0,
  });

  static const off = AdsConfig();

  AdPlacement? placement(String id) {
    for (final p in placements) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    final units = json['rewarded_ad_unit_ids'] is Map
        ? json['rewarded_ad_unit_ids'] as Map
        : const {};
    final placements = json['placements'];
    String? unit(Object? v) => v is String && v.isNotEmpty ? v : null;
    return AdsConfig(
      rewardedAdsEnabled: json['rewarded_ads_enabled'] as bool? ?? false,
      adFree: json['ad_free'] as bool? ?? false,
      androidAdUnitId: unit(units['android']),
      iosAdUnitId: unit(units['ios']),
      policy: json['policy'] is Map<String, dynamic>
          ? AdRequestPolicy.fromJson(json['policy'] as Map<String, dynamic>)
          : const AdRequestPolicy(),
      placements: placements is List
          ? [
              for (final p in placements)
                if (p is Map<String, dynamic>) AdPlacement.fromJson(p),
            ]
          : const [],
      remainingToday: (json['remaining_today'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One ad reward on the server: requested, then paid after Google's callback.
enum AdRewardStatus { pending, fulfilled, expired }

@immutable
class AdReward {
  final String id;
  final String placement;
  final AdRewardStatus status;
  final bool adRequired;
  final String? ssvUserId;
  final String? ssvCustomData;
  final String? rewardCurrency; // coins, gems or a power-up token
  final int rewardAmount;

  const AdReward({
    required this.id,
    required this.placement,
    required this.status,
    required this.adRequired,
    this.ssvUserId,
    this.ssvCustomData,
    this.rewardCurrency,
    this.rewardAmount = 0,
  });

  bool get isFulfilled => status == AdRewardStatus.fulfilled;

  factory AdReward.fromJson(Map<String, dynamic> json) => AdReward(
    id: json['id'] as String? ?? '',
    placement: json['placement'] as String? ?? '',
    status: switch (json['status']) {
      'fulfilled' => AdRewardStatus.fulfilled,
      'expired' => AdRewardStatus.expired,
      _ => AdRewardStatus.pending,
    },
    adRequired: json['ad_required'] as bool? ?? true,
    ssvUserId: json['ssv_user_id'] as String?,
    ssvCustomData: json['ssv_custom_data'] as String?,
    rewardCurrency: json['reward_currency'] as String?,
    rewardAmount: (json['reward_amount'] as num?)?.toInt() ?? 0,
  );
}

/// Server prices for power-ups and the player's tokens.
@immutable
class PowerUpPrice {
  final String id;
  final int priceCoins;
  final int tokens;

  const PowerUpPrice({
    required this.id,
    required this.priceCoins,
    this.tokens = 0,
  });
}

@immutable
class PowerUpsStatus {
  final Map<String, PowerUpPrice> powerUps;
  final int maxTokens;

  const PowerUpsStatus({this.powerUps = const {}, this.maxTokens = 5});

  static const empty = PowerUpsStatus();

  int tokens(String id) => powerUps[id]?.tokens ?? 0;

  factory PowerUpsStatus.fromJson(Map<String, dynamic> json) {
    final list = json['power_ups'];
    return PowerUpsStatus(
      maxTokens: (json['max_tokens'] as num?)?.toInt() ?? 5,
      powerUps: {
        if (list is List)
          for (final p in list)
            if (p is Map && p['id'] is String)
              p['id'] as String: PowerUpPrice(
                id: p['id'] as String,
                priceCoins: (p['price_coins'] as num?)?.toInt() ?? 0,
                tokens: (p['tokens'] as num?)?.toInt() ?? 0,
              ),
      },
    );
  }
}

List<String> _strings(Object? value) =>
    value is List ? [for (final v in value) v.toString()] : const [];

/// Human label for a reward currency or token.
String rewardLabel(String? currency, int amount) => switch (currency) {
  'coins' => '$amount coins',
  'gems' => '$amount gems',
  'fifty_fifty' => '$amount × 50:50',
  'add_time' => '$amount × +5 seconds',
  'skip' => '$amount × Skip',
  _ => 'a reward',
};
