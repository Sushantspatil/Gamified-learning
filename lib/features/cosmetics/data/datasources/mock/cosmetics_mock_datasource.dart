import '../../../../../core/errors/app_exception.dart';
import '../../models/cosmetic_item_model.dart';
import '../cosmetics_datasource.dart';

/// Placeholder catalog — not specified by the product requirements.
const List<CosmeticItemModel> _catalog = [
  CosmeticItemModel(
    id: 'frame-gold',
    name: 'Gold Frame',
    colorKey: 'gold',
    costCoins: 100,
  ),
  CosmeticItemModel(
    id: 'frame-cyan',
    name: 'Cyan Frame',
    colorKey: 'cyan',
    costCoins: 100,
  ),
  CosmeticItemModel(
    id: 'frame-fire',
    name: 'Fire Frame',
    colorKey: 'fire',
    costCoins: 150,
  ),
  CosmeticItemModel(
    id: 'frame-royal',
    name: 'Royal Frame',
    colorKey: 'royal',
    costCoins: 200,
  ),
];

/// MOCK DATA — replace the binding in cosmetics_providers.dart with a
/// Firestore-backed implementation when the backend is ready.
class CosmeticsMockDatasource implements CosmeticsDatasource {
  final Map<String, Set<String>> _ownedByUser = {};
  final Map<String, String> _equippedByUser = {};

  @override
  Future<List<CosmeticItemModel>> getCatalog() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _catalog;
  }

  @override
  Future<Set<String>> getOwnedCosmeticIds(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _ownedByUser[userId] ?? const {};
  }

  @override
  Future<String?> getEquippedCosmeticId(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _equippedByUser[userId];
  }

  @override
  Future<void> recordPurchase(String userId, String cosmeticId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _ownedByUser.putIfAbsent(userId, () => {}).add(cosmeticId);
  }

  @override
  Future<void> setEquipped(String userId, String cosmeticId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final owned = _ownedByUser[userId] ?? const {};
    if (!owned.contains(cosmeticId)) {
      throw const ValidationException(
        'You do not own this cosmetic yet.',
        'not-owned',
      );
    }
    _equippedByUser[userId] = cosmeticId;
  }
}
