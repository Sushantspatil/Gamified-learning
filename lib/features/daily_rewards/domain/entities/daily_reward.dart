import 'package:equatable/equatable.dart';

class DailyReward extends Equatable {
  final int cycleDay;
  final int coins;
  final bool claimedToday;

  const DailyReward({
    required this.cycleDay,
    required this.coins,
    required this.claimedToday,
  });

  @override
  List<Object?> get props => [cycleDay, coins, claimedToday];
}
