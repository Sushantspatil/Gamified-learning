import '../entities/chest_result.dart';
import '../entities/chest_type.dart';

abstract class ChestRepository {
  /// Ad chests have no daily gate (repeatable, ad-funded); only the daily
  /// chest is time-limited.
  Future<bool> isDailyChestAvailable(String userId);

  /// Throws a ValidationException if a daily chest is opened before it
  /// resets. The reward is chosen here, not by the caller or the UI.
  Future<ChestResult> openChest(String userId, ChestType type);
}
