import 'package:equatable/equatable.dart';

/// Gamification data layered on top of the auth feature's [AppUser]. Coins
/// and gems live in the wallet feature (their own auditable ledger), not
/// here — this entity is XP/level/avatar only.
class UserProfile extends Equatable {
  final String avatarId;
  final String? classLevel;
  final String? board;
  final List<String> selectedSubjectIds;
  final bool profileSetupCompleted;
  final bool tutorialCompleted;
  final int xp;
  final int level;

  const UserProfile({
    required this.avatarId,
    this.classLevel,
    this.board,
    this.selectedSubjectIds = const [],
    this.profileSetupCompleted = false,
    this.tutorialCompleted = false,
    required this.xp,
    required this.level,
  });

  static const defaultProfile = UserProfile(
    avatarId: 'default',
    xp: 0,
    level: 1,
  );

  UserProfile copyWith({
    String? avatarId,
    String? classLevel,
    String? board,
    List<String>? selectedSubjectIds,
    bool? profileSetupCompleted,
    bool? tutorialCompleted,
    int? xp,
    int? level,
  }) {
    return UserProfile(
      avatarId: avatarId ?? this.avatarId,
      classLevel: classLevel ?? this.classLevel,
      board: board ?? this.board,
      selectedSubjectIds: selectedSubjectIds ?? this.selectedSubjectIds,
      profileSetupCompleted:
          profileSetupCompleted ?? this.profileSetupCompleted,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      xp: xp ?? this.xp,
      level: level ?? this.level,
    );
  }

  @override
  List<Object?> get props => [
    avatarId,
    classLevel,
    board,
    selectedSubjectIds,
    profileSetupCompleted,
    tutorialCompleted,
    xp,
    level,
  ];
}
