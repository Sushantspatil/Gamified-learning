import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/quiz_result.dart';

/// Inbound WebSocket message wrapper (Client → Server)
class WsInboundMessage {
  final String type;
  final Map<String, dynamic> data;

  const WsInboundMessage({required this.type, required this.data});

  Map<String, dynamic> toJson() => {'type': type, 'data': data};

  /// Factory for 'join_game' message
  factory WsInboundMessage.joinGame({String? session}) {
    return WsInboundMessage(
      type: 'join_game',
      data: {if (session != null && session.isNotEmpty) 'session': session},
    );
  }

  /// Factory for 'submit_answer' message
  factory WsInboundMessage.submitAnswer({
    required String question,
    required String option,
    String? selectedText,
    int timeTakenMs = 0,
    String? session,
  }) {
    return WsInboundMessage(
      type: 'submit_answer',
      data: {
        if (session != null && session.isNotEmpty) 'session': session,
        'question': question,
        'option': option,
        if (selectedText != null && selectedText.isNotEmpty)
          'selected_text': selectedText,
        'time_taken_ms': timeTakenMs,
      },
    );
  }

  /// Factory for 'use_power_up' message
  factory WsInboundMessage.usePowerUp({
    required String question,
    String powerUp = 'fifty_fifty',
    String? session,
  }) {
    return WsInboundMessage(
      type: 'use_power_up',
      data: {
        if (session != null && session.isNotEmpty) 'session': session,
        'question': question,
        'power_up': powerUp,
      },
    );
  }
}

/// Outbound Option payload in 'question' frame
class WsOptionPayload {
  final String option;
  final String text;

  const WsOptionPayload({required this.option, required this.text});

  factory WsOptionPayload.fromJson(Map<String, dynamic> json) {
    return WsOptionPayload(
      option: json['option'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'option': option, 'text': text};
}

/// Outbound Question payload in 'question' frame (Server → Client)
class WsQuestionPayload {
  final String question;
  final String prompt;
  final int points;
  final String? hint;
  final List<WsOptionPayload> options;
  final int timeLimitMs;
  final int remainingTimeMs;
  final bool addTimeUsed;
  final int questionNumber;
  final int totalQuestions;

  const WsQuestionPayload({
    required this.question,
    required this.prompt,
    required this.points,
    this.hint,
    required this.options,
    required this.timeLimitMs,
    required this.remainingTimeMs,
    this.addTimeUsed = false,
    required this.questionNumber,
    required this.totalQuestions,
  });

  factory WsQuestionPayload.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return WsQuestionPayload(
      question: (json['question'] as dynamic)?.toString() ?? '',
      prompt: json['prompt'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 10,
      hint: json['hint'] as String?,
      options: rawOptions
          .map((e) => WsOptionPayload.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      timeLimitMs: (json['time_limit_ms'] as num?)?.toInt() ?? 15000,
      remainingTimeMs: (json['remaining_time_ms'] as num?)?.toInt() ?? 15000,
      addTimeUsed: json['add_time_used'] as bool? ?? false,
      questionNumber: (json['question_number'] as num?)?.toInt() ?? 1,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'prompt': prompt,
    'points': points,
    if (hint != null) 'hint': hint,
    'options': options.map((o) => o.toJson()).toList(),
    'time_limit_ms': timeLimitMs,
    'remaining_time_ms': remainingTimeMs,
    'add_time_used': addTimeUsed,
    'question_number': questionNumber,
    'total_questions': totalQuestions,
  };

  /// Converts this server-authoritative question into the domain entity.
  SuddenDeathQuestion toDomain(String topicId) {
    return SuddenDeathQuestion(
      id: question,
      topicId: topicId,
      prompt: prompt,
      points: points,
      options: options
          .map((o) => QuestionOption(id: o.option.toLowerCase(), text: o.text))
          .toList(growable: false),
      correctOptionId: '', // Hidden server-side until answer_result
    );
  }
}

/// Outbound Answer Result payload in 'answer_result' frame (Server → Client)
class WsAnswerResultPayload {
  final String question;
  final String option;
  final String correctOption;
  final bool isCorrect;
  final bool isSkipped;
  final String? explanation;
  final int pointsEarned;
  final int coinsEarned;
  final int yourScore;
  final bool isTimeout;

  const WsAnswerResultPayload({
    required this.question,
    required this.option,
    required this.correctOption,
    required this.isCorrect,
    required this.isSkipped,
    this.explanation,
    required this.pointsEarned,
    required this.coinsEarned,
    required this.yourScore,
    required this.isTimeout,
  });

  factory WsAnswerResultPayload.fromJson(Map<String, dynamic> json) {
    return WsAnswerResultPayload(
      question: (json['question'] as dynamic)?.toString() ?? '',
      option: json['option'] as String? ?? '',
      correctOption: json['correct_option'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      isSkipped: json['is_skipped'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      yourScore: (json['your_score'] as num?)?.toInt() ?? 0,
      isTimeout: json['is_timeout'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'option': option,
    'correct_option': correctOption,
    'is_correct': isCorrect,
    'is_skipped': isSkipped,
    if (explanation != null) 'explanation': explanation,
    'points_earned': pointsEarned,
    'coins_earned': coinsEarned,
    'your_score': yourScore,
    'is_timeout': isTimeout,
  };
}

/// Outbound Power Up Result payload in 'power_up_result' frame (Server → Client)
class WsPowerUpResultPayload {
  final String question;
  final String powerUp;
  final int addedTimeMs;
  final int remainingTimeMs;
  final List<String> hiddenOptions;

  const WsPowerUpResultPayload({
    required this.question,
    this.powerUp = '',
    this.addedTimeMs = 0,
    this.remainingTimeMs = 0,
    this.hiddenOptions = const [],
  });

  factory WsPowerUpResultPayload.fromJson(Map<String, dynamic> json) {
    final rawHidden = json['hidden_options'] as List<dynamic>? ?? [];
    return WsPowerUpResultPayload(
      question: (json['question'] as dynamic)?.toString() ?? '',
      powerUp: json['power_up'] as String? ?? '',
      addedTimeMs: (json['added_time_ms'] as num?)?.toInt() ?? 0,
      remainingTimeMs: (json['remaining_time_ms'] as num?)?.toInt() ?? 0,
      hiddenOptions: rawHidden
          .map((e) => e.toString().toLowerCase())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    if (powerUp.isNotEmpty) 'power_up': powerUp,
    if (addedTimeMs > 0) 'added_time_ms': addedTimeMs,
    if (remainingTimeMs > 0) 'remaining_time_ms': remainingTimeMs,
    'hidden_options': hiddenOptions,
  };
}

/// Level-up reward sub-payload in 'game_over' frame
class WsLevelUpRewardPayload {
  final int coins;
  final int xp;
  final int gems;

  const WsLevelUpRewardPayload({
    required this.coins,
    required this.xp,
    required this.gems,
  });

  factory WsLevelUpRewardPayload.fromJson(Map<String, dynamic> json) {
    return WsLevelUpRewardPayload(
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      gems: (json['gems'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'coins': coins, 'xp': xp, 'gems': gems};
}

/// Outbound Game Over payload in 'game_over' frame (Server → Client)
class WsGameOverPayload {
  final int finalScore;
  final int totalQuestions;
  final int correctCount;
  final int coinsEarned;
  final int xpEarned;
  final int gemsEarned;
  final int newLevel;
  final bool didLevelUp;
  final WsLevelUpRewardPayload? levelUpReward;

  /// Rules the session ran under, echoed by the server.
  final String gameMode;

  /// Why the run stopped: `cleared` or `eliminated`.
  final String endReason;

  /// Authoritative flag for "the run stopped before every question was
  /// answered". Null when talking to a server that predates the field, in
  /// which case callers fall back to a score-based heuristic.
  final bool? endedEarly;

  const WsGameOverPayload({
    required this.finalScore,
    required this.totalQuestions,
    required this.correctCount,
    required this.coinsEarned,
    required this.xpEarned,
    required this.gemsEarned,
    required this.newLevel,
    required this.didLevelUp,
    this.levelUpReward,
    this.gameMode = 'mcq',
    this.endReason = '',
    this.endedEarly,
  });

  /// True when the player was knocked out rather than completing the set.
  ///
  /// Prefers the server's verdict; falls back to comparing answered questions
  /// only when the field is absent.
  bool get wasEliminated => endedEarly ?? (correctCount < totalQuestions);

  /// True when the player survived every question in the set.
  bool get wasCleared => !wasEliminated;

  factory WsGameOverPayload.fromJson(Map<String, dynamic> json) {
    final rawReward = json['level_up_reward'];
    return WsGameOverPayload(
      finalScore: (json['final_score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coins_earned'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      gemsEarned: (json['gems_earned'] as num?)?.toInt() ?? 0,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 1,
      didLevelUp: json['did_level_up'] as bool? ?? false,
      levelUpReward: rawReward is Map<String, dynamic>
          ? WsLevelUpRewardPayload.fromJson(rawReward)
          : null,
      gameMode: json['game_mode'] as String? ?? 'mcq',
      endReason: json['end_reason'] as String? ?? '',
      endedEarly: json['ended_early'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    'final_score': finalScore,
    'total_questions': totalQuestions,
    'correct_count': correctCount,
    'coins_earned': coinsEarned,
    'xp_earned': xpEarned,
    'gems_earned': gemsEarned,
    'new_level': newLevel,
    'did_level_up': didLevelUp,
    if (levelUpReward != null) 'level_up_reward': levelUpReward!.toJson(),
    'game_mode': gameMode,
    'end_reason': endReason,
    if (endedEarly != null) 'ended_early': endedEarly,
  };

  /// Constructs the domain [QuizResult] from this authoritative game-over frame.
  QuizResult toQuizResult({
    required String sessionId,
    String? userId,
    String? subjectId,
    String? chapterId,
    required String topicId,
    required DateTime startedAt,
    required DateTime completedAt,
  }) {
    final maxScore = totalQuestions * 10;
    return QuizResult(
      sessionId: sessionId,
      userId: userId,
      subjectId: subjectId,
      chapterId: chapterId,
      topicId: topicId,
      quizType: QuestionType.suddenDeath,
      score: Score(
        earnedPoints: finalScore,
        maxPoints: maxScore,
        correctCount: correctCount,
        totalCount: totalQuestions,
      ),
      records: const [],
      // Use the server's verdict rather than inferring from the score: a plain
      // MCQ run can finish with fewer correct answers than total questions
      // without ever having been eliminated.
      endedEarly: wasEliminated,
      streakCount: correctCount,
      xpAwarded: xpEarned,
      coinsAwarded: coinsEarned,
      gemsAwarded: gemsEarned,
      didLevelUp: didLevelUp,
      rewardBreakdown: QuizRewardBreakdown(
        score: [
          RewardBreakdownItem(key: 'sudden_death_score', amount: finalScore),
        ],
        xp: [RewardBreakdownItem(key: 'xp_earned', amount: xpEarned)],
        coins: [RewardBreakdownItem(key: 'coins_earned', amount: coinsEarned)],
      ),
      levelProgress: QuizLevelProgress(
        currentLevel: newLevel,
        experience: xpEarned,
        nextLevelExperience: (newLevel * newLevel) * 100,
      ),
      timeTaken: completedAt.difference(startedAt),
      createdAt: completedAt,
    );
  }
}

/// Outbound Error payload in 'error' frame (Server → Client)
class WsErrorPayload {
  final String code;
  final String message;

  const WsErrorPayload({required this.code, required this.message});

  factory WsErrorPayload.fromJson(Map<String, dynamic> json) {
    return WsErrorPayload(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

/// Sealed hierarchy of all incoming server events over WebSocket
sealed class WsServerEvent {
  const WsServerEvent();

  factory WsServerEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final data = json['data'];
    final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};

    switch (type) {
      case 'question':
        return WsQuestionEvent(WsQuestionPayload.fromJson(dataMap));
      case 'answer_result':
        return WsAnswerResultEvent(WsAnswerResultPayload.fromJson(dataMap));
      case 'power_up_result':
        return WsPowerUpResultEvent(WsPowerUpResultPayload.fromJson(dataMap));
      case 'game_over':
        return WsGameOverEvent(WsGameOverPayload.fromJson(dataMap));
      case 'error':
        return WsErrorEvent(WsErrorPayload.fromJson(dataMap));
      default:
        return WsUnknownEvent(type: type, rawData: dataMap);
    }
  }
}

class WsQuestionEvent extends WsServerEvent {
  final WsQuestionPayload payload;
  const WsQuestionEvent(this.payload);
}

class WsAnswerResultEvent extends WsServerEvent {
  final WsAnswerResultPayload payload;
  const WsAnswerResultEvent(this.payload);
}

class WsPowerUpResultEvent extends WsServerEvent {
  final WsPowerUpResultPayload payload;
  const WsPowerUpResultEvent(this.payload);
}

class WsGameOverEvent extends WsServerEvent {
  final WsGameOverPayload payload;
  const WsGameOverEvent(this.payload);
}

class WsErrorEvent extends WsServerEvent {
  final WsErrorPayload payload;
  const WsErrorEvent(this.payload);
}

class WsUnknownEvent extends WsServerEvent {
  final String type;
  final Map<String, dynamic> rawData;
  const WsUnknownEvent({required this.type, required this.rawData});
}
