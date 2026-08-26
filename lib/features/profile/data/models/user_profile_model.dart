import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.avatarId,
    required super.xp,
    required super.level,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        avatarId: json['avatarId'] as String,
        xp: json['xp'] as int,
        level: json['level'] as int,
      );

  Map<String, dynamic> toJson() => {
    'avatarId': avatarId,
    'xp': xp,
    'level': level,
  };
}
