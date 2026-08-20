import 'package:equatable/equatable.dart';

class CosmeticItem extends Equatable {
  final String id;
  final String name;
  final String colorKey;
  final int costCoins;

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.costCoins,
  });

  @override
  List<Object?> get props => [id, name, colorKey, costCoins];
}
