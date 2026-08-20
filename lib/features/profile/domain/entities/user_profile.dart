import 'package:equatable/equatable.dart';

/// Gamification data layered on top of the auth feature's [AppUser]. Coins
/// and gems live in the wallet feature (their own auditable ledger), not
/// here — this entity is XP/level/avatar only.
class UserProfile extends Equatable {
  final String avatarId;
  final int xp;
  final int level;

  const UserProfile({
    required this.avatarId,
    required this.xp,
    required this.level,
  });

  static const defaultProfile = UserProfile(avatarId: 'default', xp: 0, level: 1);

  @override
  List<Object?> get props => [avatarId, xp, level];
}
