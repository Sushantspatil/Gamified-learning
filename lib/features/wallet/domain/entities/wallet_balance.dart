import 'package:equatable/equatable.dart';

class WalletBalance extends Equatable {
  final int coins;
  final int gems;

  const WalletBalance({required this.coins, required this.gems});

  static const zero = WalletBalance(coins: 0, gems: 0);

  @override
  List<Object?> get props => [coins, gems];
}
