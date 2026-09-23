/// Strongly typed DTOs for Quiz operations.
library;

class CreateSessionRequestDto {
  final String topic;
  final int questionCount;
  final bool abandonStale;
  final List<String>? questionCodes;

  const CreateSessionRequestDto({
    required this.topic,
    this.questionCount = 10,
    this.abandonStale = true,
    this.questionCodes,
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'question_count': questionCount,
    'abandon_stale': abandonStale,
    if (questionCodes != null && questionCodes!.isNotEmpty)
      'question_codes': questionCodes,
  };
}

class SessionCreatedResponseDto {
  final String session;
  final String topic;
  final int totalQuestions;
  final int timeLimitSec;
  final List<Map<String, dynamic>> questions;

  const SessionCreatedResponseDto({
    required this.session,
    required this.topic,
    required this.totalQuestions,
    required this.timeLimitSec,
    required this.questions,
  });

  factory SessionCreatedResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['questions'];
    final qList = <Map<String, dynamic>>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          qList.add(item);
        }
      }
    }
    return SessionCreatedResponseDto(
      session: json['session'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      totalQuestions: json['total_questions'] as int? ?? qList.length,
      timeLimitSec: json['time_limit_sec'] as int? ?? 15,
      questions: qList,
    );
  }
}

class EvaluateAnswerRequestDto {
  final String session;
  final String question;
  final String option;
  final String? selectedText;
  final int timeTakenMs;

  const EvaluateAnswerRequestDto({
    required this.session,
    required this.question,
    required this.option,
    this.selectedText,
    this.timeTakenMs = 3000,
  });

  Map<String, dynamic> toJson() => {
    'session': session,
    'question': question,
    'option': option,
    if (selectedText != null && selectedText!.isNotEmpty)
      'selected_text': selectedText,
    'time_taken_ms': timeTakenMs,
  };
}

class AnswerResultResponseDto {
  final String question;
  final String option;
  final String correctOption;
  final bool isCorrect;
  final bool isSkipped;
  final String? explanation;
  final int pointsEarned;
  final int coinsEarned;
  final int comboStreak;
  final int totalScore;

  const AnswerResultResponseDto({
    required this.question,
    required this.option,
    required this.correctOption,
    required this.isCorrect,
    required this.isSkipped,
    this.explanation,
    required this.pointsEarned,
    required this.coinsEarned,
    required this.comboStreak,
    required this.totalScore,
  });

  factory AnswerResultResponseDto.fromJson(Map<String, dynamic> json) =>
      AnswerResultResponseDto(
        question: json['question'] as String? ?? '',
        option: json['option'] as String? ?? '',
        correctOption: json['correct_option'] as String? ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
        isSkipped: json['is_skipped'] as bool? ?? false,
        explanation: json['explanation'] as String?,
        pointsEarned: json['points_earned'] as int? ?? 0,
        coinsEarned: json['coins_earned'] as int? ?? 0,
        comboStreak: json['combo_streak'] as int? ?? 0,
        totalScore: json['total_score'] as int? ?? 0,
      );
}

class FiftyFiftyRequestDto {
  final String session;
  final String question;

  const FiftyFiftyRequestDto({required this.session, required this.question});

  Map<String, dynamic> toJson() => {'session': session, 'question': question};
}

class FiftyFiftyResponseDto {
  final String question;
  final List<String> hiddenOptions;

  const FiftyFiftyResponseDto({
    required this.question,
    required this.hiddenOptions,
  });

  factory FiftyFiftyResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['hidden_options'];
    return FiftyFiftyResponseDto(
      question: json['question'] as String? ?? '',
      hiddenOptions: list is List
          ? list.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class CompleteSessionRequestDto {
  final String session;

  const CompleteSessionRequestDto({required this.session});

  Map<String, dynamic> toJson() => {'session': session};
}

class LevelProgressDto {
  final int current;
  final bool didLevelUp;
  final int experience;
  final int nextLevelExp;

  const LevelProgressDto({
    required this.current,
    required this.didLevelUp,
    required this.experience,
    required this.nextLevelExp,
  });

  factory LevelProgressDto.fromJson(Map<String, dynamic> json) =>
      LevelProgressDto(
        current: json['current'] as int? ?? 1,
        didLevelUp: json['did_level_up'] as bool? ?? false,
        experience: json['experience'] as int? ?? 0,
        nextLevelExp: json['next_level_exp'] as int? ?? 100,
      );
}

class StreakSummaryDto {
  final int currentStreak;
  final bool todayCompleted;

  const StreakSummaryDto({
    required this.currentStreak,
    required this.todayCompleted,
  });

  factory StreakSummaryDto.fromJson(Map<String, dynamic> json) =>
      StreakSummaryDto(
        currentStreak: json['current_streak'] as int? ?? 0,
        todayCompleted: json['today_completed'] as bool? ?? false,
      );
}

class LevelUpRewardDto {
  final int xp;
  final int coins;
  final int gems;

  const LevelUpRewardDto({
    required this.xp,
    required this.coins,
    required this.gems,
  });

  factory LevelUpRewardDto.fromJson(Map<String, dynamic> json) =>
      LevelUpRewardDto(
        xp: json['xp'] as int? ?? 0,
        coins: json['coins'] as int? ?? 0,
        gems: json['gems'] as int? ?? 0,
      );
}

class SessionCompleteResponseDto {
  final String session;
  final int? totalQuestions;
  final int? correctCount;
  final double? accuracyPercentage;
  final int? finalScore;
  final int? maxScore;
  final int coinsAwarded;
  final int xpAwarded;
  final int gemsAwarded;
  final Map<String, int> scoreBreakdown;
  final Map<String, int> coinBreakdown;
  final Map<String, int> xpBreakdown;
  final LevelUpRewardDto? levelUpReward;
  final LevelProgressDto? level;
  final StreakSummaryDto? streak;

  const SessionCompleteResponseDto({
    required this.session,
    required this.totalQuestions,
    required this.correctCount,
    required this.accuracyPercentage,
    required this.finalScore,
    required this.maxScore,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.gemsAwarded,
    this.scoreBreakdown = const {},
    this.coinBreakdown = const {},
    this.xpBreakdown = const {},
    this.levelUpReward,
    this.level,
    this.streak,
  });

  factory SessionCompleteResponseDto.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseBreakdown(Object? val) {
      if (val is! Map) return const {};
      final map = <String, int>{};
      val.forEach((k, v) {
        if (v is num) map[k.toString()] = v.round();
      });
      return map;
    }

    return SessionCompleteResponseDto(
      session: json['session'] as String? ?? '',
      totalQuestions: json['total_questions'] as int?,
      correctCount: json['correct_count'] as int?,
      accuracyPercentage: (json['accuracy_percentage'] as num?)?.toDouble(),
      finalScore: json['final_score'] as int?,
      maxScore: json['max_score'] as int?,
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      gemsAwarded: json['gems_awarded'] as int? ?? 0,
      scoreBreakdown: parseBreakdown(json['score_breakdown']),
      coinBreakdown: parseBreakdown(json['coin_breakdown']),
      xpBreakdown: parseBreakdown(json['xp_breakdown']),
      levelUpReward: json['level_up_reward'] is Map<String, dynamic>
          ? LevelUpRewardDto.fromJson(
              json['level_up_reward'] as Map<String, dynamic>,
            )
          : null,
      level: json['level'] is Map<String, dynamic>
          ? LevelProgressDto.fromJson(json['level'] as Map<String, dynamic>)
          : null,
      streak: json['streak'] is Map<String, dynamic>
          ? StreakSummaryDto.fromJson(json['streak'] as Map<String, dynamic>)
          : null,
    );
  }
}
