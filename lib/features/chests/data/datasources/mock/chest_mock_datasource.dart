import 'dart:math';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/utils/date_key.dart';
import '../../../../wallet/domain/entities/currency_type.dart';
import '../../../domain/entities/chest_type.dart';
import '../../models/chest_result_model.dart';
import '../chest_datasource.dart';

class _Reward {
  final CurrencyType currency;
  final int amount;

  const _Reward(this.currency, this.amount);
}

/// Placeholder reward pools — not specified by the product requirements.
const List<_Reward> _dailyChestRewards = [
  _Reward(CurrencyType.coins, 50),
  _Reward(CurrencyType.coins, 100),
  _Reward(CurrencyType.gems, 10),
];

const List<_Reward> _adChestRewards = [
  _Reward(CurrencyType.coins, 20),
  _Reward(CurrencyType.coins, 40),
  _Reward(CurrencyType.gems, 5),
];

/// MOCK DATA — this is the only place chest outcomes are decided. Replace
/// the binding in chest_providers.dart with a datasource that calls a Cloud
/// Function once results must be server-authoritative; nothing above this
/// layer (controller, widgets) needs to change when that happens.
class ChestMockDatasource implements ChestDatasource {
  final Map<String, String> _lastDailyOpenDateKeyByUser = {};
  final Random _random;

  ChestMockDatasource({Random? random}) : _random = random ?? Random();

  @override
  Future<bool> isDailyChestAvailable(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final today = dateKey(DateTime.now());
    return _lastDailyOpenDateKeyByUser[userId] != today;
  }

  @override
  Future<ChestResultModel> openChest(String userId, ChestType type) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (type == ChestType.daily) {
      final today = dateKey(DateTime.now());
      if (_lastDailyOpenDateKeyByUser[userId] == today) {
        throw const ValidationException('The daily chest has already been opened today.', 'already-opened');
      }
      _lastDailyOpenDateKeyByUser[userId] = today;
    }

    final pool = type == ChestType.daily ? _dailyChestRewards : _adChestRewards;
    final reward = pool[_random.nextInt(pool.length)];

    return ChestResultModel(chestType: type, currency: reward.currency, amount: reward.amount);
  }
}
