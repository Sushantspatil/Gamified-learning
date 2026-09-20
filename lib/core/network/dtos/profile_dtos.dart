/// Strongly typed DTOs for Profile requests and responses.
library;

class ProfileSetupRequestDto {
  final String avatarId;
  final String name;
  final String classLevel;
  final String board;
  final List<String> subjects;

  const ProfileSetupRequestDto({
    required this.avatarId,
    required this.name,
    required this.classLevel,
    required this.board,
    required this.subjects,
  });

  Map<String, dynamic> toJson() => {
    'avatarId': avatarId,
    'name': name.trim(),
    'class': classLevel.trim(),
    'board': board.trim(),
    'subjects': subjects,
  };
}

class ProfileUpdateRequestDto {
  final String? name;
  final String? phone;
  final String? avatarId;
  final String? avatarUrl;
  final String? classLevel;
  final String? board;
  final List<String>? subjects;

  const ProfileUpdateRequestDto({
    this.name,
    this.phone,
    this.avatarId,
    this.avatarUrl,
    this.classLevel,
    this.board,
    this.subjects,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name!.trim(),
    if (phone != null) 'phone': phone!.trim(),
    if (avatarId != null) 'avatarId': avatarId,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (classLevel != null) 'class': classLevel!.trim(),
    if (board != null) 'board': board!.trim(),
    if (subjects != null) 'subjects': subjects,
  };
}

class ProfileResponseDto {
  final String uuid;
  final String name;
  final String? phone;
  final String email;
  final String avatarId;
  final String? avatarUrl;
  final String? classLevel;
  final String? board;
  final List<String> subjects;
  final bool isOnboarded;
  final int streaks;
  final int highestStreak;
  final int gems;
  final int coins;
  final int level;
  final int experience;
  final int nextLevelExp;
  final int weeklyScore;
  final int weeklyRank;

  const ProfileResponseDto({
    required this.uuid,
    required this.name,
    this.phone,
    required this.email,
    required this.avatarId,
    this.avatarUrl,
    this.classLevel,
    this.board,
    this.subjects = const [],
    this.isOnboarded = false,
    this.streaks = 0,
    this.highestStreak = 0,
    this.gems = 0,
    this.coins = 0,
    this.level = 1,
    this.experience = 0,
    this.nextLevelExp = 100,
    this.weeklyScore = 0,
    this.weeklyRank = 0,
  });

  factory ProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      ProfileResponseDto(
        uuid: json['uuid']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String? ?? '',
        avatarId: json['avatarId'] as String? ?? 'avatar-1',
        avatarUrl: json['avatarUrl'] as String?,
        classLevel: json['class'] as String? ?? json['classLevel'] as String?,
        board: json['board'] as String?,
        subjects: json['subjects'] is List
            ? (json['subjects'] as List).map((e) => e.toString()).toList()
            : const [],
        isOnboarded: json['isOnboarded'] as bool? ?? false,
        streaks: json['streaks'] as int? ?? 0,
        highestStreak: json['highestStreak'] as int? ?? 0,
        gems: json['gems'] as int? ?? 0,
        coins: json['coins'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        experience: json['experience'] as int? ?? 0,
        nextLevelExp: json['nextLevelExp'] as int? ?? 100,
        weeklyScore: json['weeklyScore'] as int? ?? 0,
        weeklyRank: json['weeklyRank'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'name': name,
    'phone': phone,
    'email': email,
    'avatarId': avatarId,
    'avatarUrl': avatarUrl,
    'class': classLevel,
    'board': board,
    'subjects': subjects,
    'isOnboarded': isOnboarded,
    'streaks': streaks,
    'highestStreak': highestStreak,
    'gems': gems,
    'coins': coins,
    'level': level,
    'experience': experience,
    'nextLevelExp': nextLevelExp,
    'weeklyScore': weeklyScore,
    'weeklyRank': weeklyRank,
  };
}
