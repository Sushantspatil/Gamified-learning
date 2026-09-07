import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.avatarId,
    super.classLevel,
    super.board,
    super.selectedSubjectIds,
    super.profileSetupCompleted,
    super.tutorialCompleted,
    required super.xp,
    required super.level,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        avatarId: json['avatarId'] as String,
        classLevel: json['classLevel'] as String?,
        board: json['board'] as String?,
        selectedSubjectIds:
            (json['selectedSubjectIds'] as List<dynamic>?)
                ?.map((id) => id as String)
                .toList() ??
            const [],
        profileSetupCompleted: json['profileSetupCompleted'] as bool? ?? false,
        tutorialCompleted: json['tutorialCompleted'] as bool? ?? false,
        xp: json['xp'] as int,
        level: json['level'] as int,
      );

  factory UserProfileModel.fromEntity(UserProfile profile) => UserProfileModel(
    avatarId: profile.avatarId,
    classLevel: profile.classLevel,
    board: profile.board,
    selectedSubjectIds: profile.selectedSubjectIds,
    profileSetupCompleted: profile.profileSetupCompleted,
    tutorialCompleted: profile.tutorialCompleted,
    xp: profile.xp,
    level: profile.level,
  );

  Map<String, dynamic> toJson() => {
    'avatarId': avatarId,
    'classLevel': classLevel,
    'board': board,
    'selectedSubjectIds': selectedSubjectIds,
    'profileSetupCompleted': profileSetupCompleted,
    'tutorialCompleted': tutorialCompleted,
    'xp': xp,
    'level': level,
  };
}
