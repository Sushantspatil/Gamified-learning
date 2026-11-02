import 'dart:convert';

import '../../../core/storage/local_storage_service.dart';
import '../domain/rewards_models.dart';
import 'rewards_catalog.dart';

/// Saves and loads [RewardsState] as one JSON value in local storage.
/// With no storage (e.g. in tests that do not provide one) it is a no-op.
class RewardsStore {
  static const String key = 'rewards_state_v1';
  static const int _maxProcessedIds = 100;

  final LocalStorageService? _storage;

  const RewardsStore(this._storage);

  /// The saved state, or null if nothing valid is saved. Bad individual
  /// fields fall back to safe defaults; a missing or invalid coin balance
  /// counts as "no saved state" so the new-profile balance is applied.
  RewardsState? load() {
    final raw = _storage?.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final coins = json['coins'];
      if (coins is! int || coins < 0) return null;

      final ids = (json['processedQuizIds'] as List? ?? const [])
          .whereType<String>()
          .toList();
      final progress = json['chestProgress'];
      final pending = json['pendingSpinReward'];
      return RewardsState(
        coins: coins,
        lastSpinDate: _string(json['lastSpinDate']),
        lastSpinReward: _int(json['lastSpinReward']),
        pendingSpinReward: pending is int && _isWheelPrize(pending)
            ? pending
            : null,
        chestProgress: progress is int
            ? progress.clamp(0, RewardsState.chestTarget)
            : 0,
        processedQuizIds: ids.length > _maxProcessedIds
            ? ids.sublist(ids.length - _maxProcessedIds)
            : ids,
        ownedAvatars: _knownIds(json['ownedAvatars'], ProductKind.avatar),
        ownedFrames: _knownIds(json['ownedFrames'], ProductKind.frame),
        equippedAvatar: _string(json['equippedAvatar']),
        equippedFrame: _string(json['equippedFrame']),
        powerUps: _powerUps(json['powerUps']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RewardsState state) async {
    final ids = state.processedQuizIds;
    final json = {
      'coins': state.coins,
      'lastSpinDate': state.lastSpinDate,
      'lastSpinReward': state.lastSpinReward,
      'pendingSpinReward': state.pendingSpinReward,
      'chestProgress': state.chestProgress,
      'processedQuizIds': ids.length > _maxProcessedIds
          ? ids.sublist(ids.length - _maxProcessedIds)
          : ids,
      'ownedAvatars': state.ownedAvatars.toList(),
      'ownedFrames': state.ownedFrames.toList(),
      'equippedAvatar': state.equippedAvatar,
      'equippedFrame': state.equippedFrame,
      'powerUps': {
        for (final entry in state.powerUps.entries) entry.key.name: entry.value,
      },
    };
    try {
      await _storage?.setString(key, jsonEncode(json));
    } catch (_) {
      // Persistence is best effort; the in-memory state stays correct.
    }
  }

  static String? _string(Object? value) => value is String ? value : null;
  static int? _int(Object? value) => value is int ? value : null;

  static bool _isWheelPrize(int coins) =>
      RewardsCatalog.wheel.any((segment) => segment.coins == coins);

  static Set<String> _knownIds(Object? value, ProductKind kind) {
    if (value is! List) return const {};
    return value
        .whereType<String>()
        .where((id) => RewardsCatalog.byId(id)?.kind == kind)
        .toSet();
  }

  static Map<PowerUpType, int> _powerUps(Object? value) {
    if (value is! Map) return const {};
    final result = <PowerUpType, int>{};
    for (final type in PowerUpType.values) {
      final count = value[type.name];
      if (count is int && count > 0) result[type] = count;
    }
    return result;
  }
}
