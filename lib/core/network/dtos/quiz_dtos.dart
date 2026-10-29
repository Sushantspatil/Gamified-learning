/// Strongly typed DTOs for Quiz operations.
library;

class CreateSessionRequestDto {
  final String topic;
  final int questionCount;
  final bool abandonStale;
  final List<String>? questionCodes;

  /// Server-side rules for the session. `sudden_death` ends the run on the
  /// first wrong answer; `sort_it_out` provides rapid-fire binary swipes;
  /// omitted keeps the default `mcq` flow.
  final String? gameMode;

  /// Optional chapter number within [topic]; null plays the whole subject.
  final int? chapterNo;

  /// Optional Sort It Out set code (e.g. 'acc11-02-set-001').
  final String? pairType;

  /// Optional per-question timer limit for `sort_it_out` in seconds (5-10, default 7).
  final int? timeLimitPerQuestionSec;

  const CreateSessionRequestDto({
    required this.topic,
    this.questionCount = 10,
    this.abandonStale = true,
    this.questionCodes,
    this.gameMode,
    this.chapterNo,
    this.pairType,
    this.timeLimitPerQuestionSec,
  });

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'question_count': questionCount,
    'abandon_stale': abandonStale,
    if (questionCodes != null && questionCodes!.isNotEmpty)
      'question_codes': questionCodes,
    if (gameMode != null && gameMode!.isNotEmpty) 'game_mode': gameMode,
    if (chapterNo != null) 'chapter_no': chapterNo,
    if (pairType != null && pairType!.isNotEmpty) 'pair_type': pairType,
    if (timeLimitPerQuestionSec != null)
      'time_limit_per_question_sec': timeLimitPerQuestionSec,
  };
}

class SessionCreatedResponseDto {
  final String session;
  final String topic;
  final int totalQuestions;
  final int timeLimitSec;
  final List<Map<String, dynamic>> questions;

  /// Mode the server actually persisted, echoed back for confirmation.
  final String gameMode;

  /// Pair classification for Sort It Out mode (Sort It Out set code, e.g. 'acc11-02-set-001').
  final String? pairType;

  /// Per-question timer limit returned by backend for rapid-fire cards.
  final int? timeLimitPerQuestionSec;

  /// Match the Following boards returned upfront for multi-board sessions.
  final List<MatchBoardDto>? boards;

  const SessionCreatedResponseDto({
    required this.session,
    required this.topic,
    required this.totalQuestions,
    required this.timeLimitSec,
    required this.questions,
    this.boards,
    this.gameMode = 'mcq',
    this.pairType,
    this.timeLimitPerQuestionSec,
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

    final boardList = json['boards'];
    final bList = <MatchBoardDto>[];
    if (boardList is List) {
      for (final item in boardList) {
        if (item is Map<String, dynamic>) {
          bList.add(MatchBoardDto.fromJson(item));
        }
      }
    }

    return SessionCreatedResponseDto(
      session: json['session'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      totalQuestions: json['total_questions'] as int? ??
          (qList.isNotEmpty ? qList.length : bList.length),
      timeLimitSec: json['time_limit_sec'] as int? ?? 15,
      questions: qList,
      boards: bList.isNotEmpty ? bList : null,
      gameMode: json['game_mode'] as String? ?? 'mcq',
      pairType: json['pair_type'] as String?,
      timeLimitPerQuestionSec: json['time_limit_per_question_sec'] as int?,
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

// --- Sort It Out Mini-Game DTOs ---

class SortItOutAnswerSubmissionDto {
  final String question;
  final String option;
  final int timeTakenMs;
  final bool isTimeout;

  const SortItOutAnswerSubmissionDto({
    required this.question,
    required this.option,
    required this.timeTakenMs,
    this.isTimeout = false,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'option': option,
    'time_taken_ms': timeTakenMs,
    if (isTimeout) 'is_timeout': true,
  };

  factory SortItOutAnswerSubmissionDto.fromJson(Map<String, dynamic> json) =>
      SortItOutAnswerSubmissionDto(
        question: json['question'] as String? ?? '',
        option: json['option'] as String? ?? '',
        timeTakenMs: json['time_taken_ms'] as int? ?? 0,
        isTimeout: json['is_timeout'] as bool? ?? false,
      );
}

class CompleteSortItOutRequestDto {
  final String session;
  final List<SortItOutAnswerSubmissionDto> answers;

  const CompleteSortItOutRequestDto({
    required this.session,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
    'session': session,
    'answers': answers.map((a) => a.toJson()).toList(),
  };
}

class SortItOutCardReviewDto {
  final String question;
  final String prompt;
  final String selectedOption;
  final String correctOption;
  final bool isCorrect;
  final bool isTimeout;
  final int timeTakenMs;
  final int basePoints;
  final int speedBonus;
  final int comboBonus;
  final int pointsEarned;
  final String? explanation;

  const SortItOutCardReviewDto({
    required this.question,
    required this.prompt,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
    required this.isTimeout,
    required this.timeTakenMs,
    required this.basePoints,
    required this.speedBonus,
    required this.comboBonus,
    required this.pointsEarned,
    this.explanation,
  });

  factory SortItOutCardReviewDto.fromJson(Map<String, dynamic> json) =>
      SortItOutCardReviewDto(
        question: json['question'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        selectedOption: json['selected_option'] as String? ?? '',
        correctOption: json['correct_option'] as String? ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
        isTimeout: json['is_timeout'] as bool? ?? false,
        timeTakenMs: json['time_taken_ms'] as int? ?? 0,
        basePoints: json['base_points'] as int? ?? 0,
        speedBonus: json['speed_bonus'] as int? ?? 0,
        comboBonus: json['combo_bonus'] as int? ?? 0,
        pointsEarned: json['points_earned'] as int? ?? 0,
        explanation: json['explanation'] as String?,
      );
}

class CompleteSortItOutResponseDto {
  final String session;
  final String pairType;
  final int totalQuestions;
  final int correctCount;
  final int timeoutCount;
  final int bestStreak;
  final double accuracyPercentage;
  final int finalScore;
  final int coinsAwarded;
  final int xpAwarded;
  final int gemsAwarded;
  final Map<String, int> scoreBreakdown;
  final Map<String, int> coinBreakdown;
  final Map<String, int> xpBreakdown;
  final LevelUpRewardDto? levelUpReward;
  final LevelProgressDto? level;
  final StreakSummaryDto? streak;
  final List<SortItOutCardReviewDto> cardsReview;

  const CompleteSortItOutResponseDto({
    required this.session,
    required this.pairType,
    required this.totalQuestions,
    required this.correctCount,
    required this.timeoutCount,
    required this.bestStreak,
    required this.accuracyPercentage,
    required this.finalScore,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.gemsAwarded,
    this.scoreBreakdown = const {},
    this.coinBreakdown = const {},
    this.xpBreakdown = const {},
    this.levelUpReward,
    this.level,
    this.streak,
    this.cardsReview = const [],
  });

  factory CompleteSortItOutResponseDto.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseBreakdown(Object? val) {
      if (val is! Map) return const {};
      final map = <String, int>{};
      val.forEach((k, v) {
        if (v is num) map[k.toString()] = v.round();
      });
      return map;
    }

    final reviewList = json['cards_review'];
    final parsedReviews = <SortItOutCardReviewDto>[];
    if (reviewList is List) {
      for (final item in reviewList) {
        if (item is Map<String, dynamic>) {
          parsedReviews.add(SortItOutCardReviewDto.fromJson(item));
        }
      }
    }

    return CompleteSortItOutResponseDto(
      session: json['session'] as String? ?? '',
      pairType: json['pair_type'] as String? ?? '',
      totalQuestions: json['total_questions'] as int? ?? parsedReviews.length,
      correctCount: json['correct_count'] as int? ?? 0,
      timeoutCount: json['timeout_count'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      accuracyPercentage:
          (json['accuracy_percentage'] as num?)?.toDouble() ?? 0.0,
      finalScore: json['final_score'] as int? ?? 0,
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
      cardsReview: parsedReviews,
    );
  }
}

// --- Match the Following Mini-Game DTOs ---

class MatchPairItemDto {
  final String id;
  final String text;

  const MatchPairItemDto({
    required this.id,
    required this.text,
  });

  factory MatchPairItemDto.fromJson(Map<String, dynamic> json) =>
      MatchPairItemDto(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
      };
}

class MatchBoardDto {
  final String questionCode;
  final String prompt;
  final int timeLimitSec;
  final List<MatchPairItemDto> leftItems;
  final List<MatchPairItemDto> rightItems;
  final Map<String, String> solutionMap;
  final String? hint;
  final String? explanation;

  const MatchBoardDto({
    required this.questionCode,
    required this.prompt,
    required this.timeLimitSec,
    required this.leftItems,
    required this.rightItems,
    this.solutionMap = const {},
    this.hint,
    this.explanation,
  });

  factory MatchBoardDto.fromJson(Map<String, dynamic> json) {
    final leftList = json['left_items'];
    final lefts = <MatchPairItemDto>[];
    if (leftList is List) {
      for (final item in leftList) {
        if (item is Map<String, dynamic>) {
          lefts.add(MatchPairItemDto.fromJson(item));
        }
      }
    }

    final rightList = json['right_items'];
    final rights = <MatchPairItemDto>[];
    if (rightList is List) {
      for (final item in rightList) {
        if (item is Map<String, dynamic>) {
          rights.add(MatchPairItemDto.fromJson(item));
        }
      }
    }

    final sol = <String, String>{};
    final solMap = json['solution_map'];
    if (solMap is Map) {
      solMap.forEach((k, v) {
        sol[k.toString()] = v.toString();
      });
    }

    return MatchBoardDto(
      questionCode: json['question_code'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      timeLimitSec: json['time_limit_sec'] as int? ?? 25,
      leftItems: lefts,
      rightItems: rights,
      solutionMap: sol,
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_code': questionCode,
        'prompt': prompt,
        'time_limit_sec': timeLimitSec,
        'left_items': leftItems.map((i) => i.toJson()).toList(),
        'right_items': rightItems.map((i) => i.toJson()).toList(),
        'solution_map': solutionMap,
        if (hint != null) 'hint': hint,
        if (explanation != null) 'explanation': explanation,
      };
}

class MatchBoardAnswerSubmissionDto {
  final String questionCode;
  final Map<String, String> matches;
  final int mistakes;
  final int timeTakenMs;
  final bool isTimeout;

  const MatchBoardAnswerSubmissionDto({
    required this.questionCode,
    required this.matches,
    this.mistakes = 0,
    required this.timeTakenMs,
    this.isTimeout = false,
  });

  Map<String, dynamic> toJson() => {
        'question_code': questionCode,
        'matches': matches,
        'mistakes': mistakes,
        'time_taken_ms': timeTakenMs,
        if (isTimeout) 'is_timeout': true,
      };

  factory MatchBoardAnswerSubmissionDto.fromJson(Map<String, dynamic> json) {
    final matchesMap = <String, String>{};
    final m = json['matches'];
    if (m is Map) {
      m.forEach((k, v) => matchesMap[k.toString()] = v.toString());
    }
    return MatchBoardAnswerSubmissionDto(
      questionCode: json['question_code'] as String? ?? '',
      matches: matchesMap,
      mistakes: json['mistakes'] as int? ?? 0,
      timeTakenMs: json['time_taken_ms'] as int? ?? 0,
      isTimeout: json['is_timeout'] as bool? ?? false,
    );
  }
}

class CompleteMatchTheFollowingRequestDto {
  final String session;
  final List<MatchBoardAnswerSubmissionDto> boards;

  const CompleteMatchTheFollowingRequestDto({
    required this.session,
    required this.boards,
  });

  Map<String, dynamic> toJson() => {
        'session': session,
        'boards': boards.map((b) => b.toJson()).toList(),
      };
}

class MatchBoardReviewDto {
  final String questionCode;
  final String prompt;
  final int pairsMatched;
  final int totalPairs;
  final int mistakes;
  final int timeTakenMs;
  final bool isFlawless;
  final bool isTimeout;
  final int basePoints;
  final int flawlessBonus;
  final int speedBonus;
  final int mistakePenalty;
  final int totalBoardScore;
  final String? explanation;

  const MatchBoardReviewDto({
    required this.questionCode,
    required this.prompt,
    required this.pairsMatched,
    required this.totalPairs,
    required this.mistakes,
    required this.timeTakenMs,
    required this.isFlawless,
    required this.isTimeout,
    required this.basePoints,
    required this.flawlessBonus,
    required this.speedBonus,
    required this.mistakePenalty,
    required this.totalBoardScore,
    this.explanation,
  });

  factory MatchBoardReviewDto.fromJson(Map<String, dynamic> json) =>
      MatchBoardReviewDto(
        questionCode: json['question_code'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        pairsMatched: json['pairs_matched'] as int? ?? 0,
        totalPairs: json['total_pairs'] as int? ?? 0,
        mistakes: json['mistakes'] as int? ?? 0,
        timeTakenMs: json['time_taken_ms'] as int? ?? 0,
        isFlawless: json['is_flawless'] as bool? ?? false,
        isTimeout: json['is_timeout'] as bool? ?? false,
        basePoints: json['base_points'] as int? ?? 0,
        flawlessBonus: json['flawless_bonus'] as int? ?? 0,
        speedBonus: json['speed_bonus'] as int? ?? 0,
        mistakePenalty: json['mistake_penalty'] as int? ?? 0,
        totalBoardScore: json['total_board_score'] as int? ?? 0,
        explanation: json['explanation'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'question_code': questionCode,
        'prompt': prompt,
        'pairs_matched': pairsMatched,
        'total_pairs': totalPairs,
        'mistakes': mistakes,
        'time_taken_ms': timeTakenMs,
        'is_flawless': isFlawless,
        'is_timeout': isTimeout,
        'base_points': basePoints,
        'flawless_bonus': flawlessBonus,
        'speed_bonus': speedBonus,
        'mistake_penalty': mistakePenalty,
        'total_board_score': totalBoardScore,
        if (explanation != null) 'explanation': explanation,
      };
}

class CompleteMatchTheFollowingResponseDto {
  final String session;
  final int totalBoards;
  final int clearedBoards;
  final int totalPairsMatched;
  final int totalPairsCount;
  final int totalMistakes;
  final double accuracyPercentage;
  final int finalScore;
  final int coinsAwarded;
  final int xpAwarded;
  final int gemsAwarded;
  final Map<String, int> scoreBreakdown;
  final Map<String, int> coinBreakdown;
  final Map<String, int> xpBreakdown;
  final LevelUpRewardDto? levelUpReward;
  final LevelProgressDto? level;
  final StreakSummaryDto? streak;
  final List<MatchBoardReviewDto> boardsReview;

  const CompleteMatchTheFollowingResponseDto({
    required this.session,
    required this.totalBoards,
    required this.clearedBoards,
    required this.totalPairsMatched,
    required this.totalPairsCount,
    required this.totalMistakes,
    required this.accuracyPercentage,
    required this.finalScore,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.gemsAwarded,
    this.scoreBreakdown = const {},
    this.coinBreakdown = const {},
    this.xpBreakdown = const {},
    this.levelUpReward,
    this.level,
    this.streak,
    this.boardsReview = const [],
  });

  factory CompleteMatchTheFollowingResponseDto.fromJson(
      Map<String, dynamic> json) {
    Map<String, int> parseBreakdown(Object? val) {
      if (val is! Map) return const {};
      final map = <String, int>{};
      val.forEach((k, v) {
        if (v is num) map[k.toString()] = v.round();
      });
      return map;
    }

    final reviewList = json['boards_review'];
    final parsedReviews = <MatchBoardReviewDto>[];
    if (reviewList is List) {
      for (final item in reviewList) {
        if (item is Map<String, dynamic>) {
          parsedReviews.add(MatchBoardReviewDto.fromJson(item));
        }
      }
    }

    return CompleteMatchTheFollowingResponseDto(
      session: json['session'] as String? ?? '',
      totalBoards: json['total_boards'] as int? ?? parsedReviews.length,
      clearedBoards: json['cleared_boards'] as int? ?? 0,
      totalPairsMatched: json['total_pairs_matched'] as int? ?? 0,
      totalPairsCount: json['total_pairs_count'] as int? ?? 0,
      totalMistakes: json['total_mistakes'] as int? ?? 0,
      accuracyPercentage:
          (json['accuracy_percentage'] as num?)?.toDouble() ?? 0.0,
      finalScore: json['final_score'] as int? ?? 0,
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
      boardsReview: parsedReviews,
    );
  }
}


