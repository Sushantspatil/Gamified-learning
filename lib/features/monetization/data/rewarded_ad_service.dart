import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/monetization_models.dart';

enum RewardedAdOutcome {
  /// The player watched to the end; Google now calls our server, which pays.
  earned,

  /// Closed before the reward.
  dismissed,

  /// No ad to show (no fill, offline, consent not given).
  unavailable,
}

/// Shows one rewarded ad. Only ever started by an explicit tap: the app has
/// no interstitial, banner or forced ads.
abstract class RewardedAdService {
  Future<RewardedAdOutcome> show({
    required String adUnitId,
    required AdRequestPolicy policy,
    required String ssvUserId,
    required String ssvCustomData,
  });
}

/// Used where rewarded ads are not supported (tests, web, desktop).
class UnavailableRewardedAdService implements RewardedAdService {
  const UnavailableRewardedAdService();

  @override
  Future<RewardedAdOutcome> show({
    required String adUnitId,
    required AdRequestPolicy policy,
    required String ssvUserId,
    required String ssvCustomData,
  }) async => RewardedAdOutcome.unavailable;
}

class GoogleRewardedAdService implements RewardedAdService {
  Future<bool>? _ready;

  /// Consent (Google UMP), age treatment and SDK start, once per app run.
  Future<bool> _prepare(AdRequestPolicy policy) => _ready ??= () async {
    final underAge = policy.ageTreatment != 'unspecified';
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: underAge),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!consent.isCompleted) consent.complete();
      }),
      (_) {
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    if (!await ConsentInformation.instance.canRequestAds()) return false;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: policy.maxAdContentRating,
        // ignore: deprecated_member_use
        ageRestrictedTreatment: switch (policy.ageTreatment) {
          // ignore: deprecated_member_use
          'child' => AgeRestrictedTreatment.child,
          // ignore: deprecated_member_use
          'unspecified' => AgeRestrictedTreatment.unspecified,
          // ignore: deprecated_member_use
          _ => AgeRestrictedTreatment.teen,
        },
      ),
    );
    await MobileAds.instance.initialize();
    return true;
  }();

  @override
  Future<RewardedAdOutcome> show({
    required String adUnitId,
    required AdRequestPolicy policy,
    required String ssvUserId,
    required String ssvCustomData,
  }) async {
    try {
      if (!await _prepare(policy)) {
        _ready = null; // ask again next time
        return RewardedAdOutcome.unavailable;
      }
      final loaded = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: AdRequest(nonPersonalizedAds: policy.nonPersonalized),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: loaded.complete,
          onAdFailedToLoad: (_) => loaded.complete(null),
        ),
      );
      final ad = await loaded.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      if (ad == null) return RewardedAdOutcome.unavailable;

      // Google sends these to our server with the signed reward callback.
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(
          userId: ssvUserId,
          customData: ssvCustomData,
        ),
      );
      var earned = false;
      final closed = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!closed.isCompleted) closed.complete();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future;
      return earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed;
    } catch (_) {
      return RewardedAdOutcome.unavailable;
    }
  }
}
