import '../../domain/entities/chest_type.dart';
import '../models/chest_result_model.dart';

/// Implemented today by [ChestMockDatasource]. Swap for a datasource that
/// calls a Cloud Function once chest outcomes must be server-authoritative
/// (Step 10) — the reward-picking logic lives only here, never in the UI.
abstract class ChestDatasource {
  Future<bool> isDailyChestAvailable(String userId);

  Future<ChestResultModel> openChest(String userId, ChestType type);
}
