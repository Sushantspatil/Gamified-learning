import 'package:equatable/equatable.dart';

class Streak extends Equatable {
  final int currentStreak;
  final String? lastActiveDateKey;

  const Streak({required this.currentStreak, required this.lastActiveDateKey});

  static const empty = Streak(currentStreak: 0, lastActiveDateKey: null);

  @override
  List<Object?> get props => [currentStreak, lastActiveDateKey];
}
