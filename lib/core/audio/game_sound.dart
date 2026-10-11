/// Central enumeration of all game sound effects in the application.
enum GameSound {
  buttonTap,
  answerSelect,
  correct,
  wrong,
  nextQuestion,
  countdownTick,
  coinReward,
  xpReward,
  streak,
  streakMilestone,
  powerUp,
  addTime,
  skip,
  timeout,
  quizComplete,
  perfectScore,
  levelUp,
  matchConnect,
  cardDrop,
}

extension GameSoundX on GameSound {
  /// Base file name for this sound inside assets/audio/sfx/.
  String get fileName => switch (this) {
    GameSound.buttonTap => 'ui_tap.mp3',
    GameSound.answerSelect => 'answer_select.mp3',
    GameSound.correct => 'answer_correct.mp3',
    GameSound.wrong => 'answer_wrong.mp3',
    GameSound.nextQuestion => 'next_question.mp3',
    GameSound.countdownTick => 'countdown_tick.mp3',
    GameSound.coinReward => 'coin_reward.mp3',
    GameSound.xpReward => 'xp_reward.mp3',
    GameSound.streak => 'streak_up.mp3',
    GameSound.streakMilestone => 'streak_milestone.mp3',
    GameSound.powerUp => 'power_up.mp3',
    GameSound.addTime => 'add_time.mp3',
    GameSound.skip => 'skip.mp3',
    GameSound.timeout => 'timeout.mp3',
    GameSound.quizComplete => 'quiz_complete.mp3',
    GameSound.perfectScore => 'perfect_score.mp3',
    GameSound.levelUp => 'level_up.mp3',
    GameSound.matchConnect => 'match_connect.mp3',
    GameSound.cardDrop => 'card_drop.mp3',
  };

  /// Relative path under assets/ for [AssetSource] playback.
  String get assetPath => 'audio/sfx/$fileName';

  /// Full asset path including the root prefix.
  String get fullAssetPath => 'assets/audio/sfx/$fileName';

  /// Standardized relative volume for balanced acoustic experience.
  double get defaultVolume => switch (this) {
    GameSound.buttonTap => 0.30,
    GameSound.answerSelect => 0.35,
    GameSound.correct => 0.60,
    GameSound.wrong => 0.50,
    GameSound.nextQuestion => 0.35,
    GameSound.countdownTick => 0.35,
    GameSound.coinReward => 0.55,
    GameSound.xpReward => 0.55,
    GameSound.streak => 0.55,
    GameSound.streakMilestone => 0.70,
    GameSound.powerUp => 0.60,
    GameSound.addTime => 0.60,
    GameSound.skip => 0.50,
    GameSound.timeout => 0.60,
    GameSound.quizComplete => 0.75,
    GameSound.perfectScore => 0.80,
    GameSound.levelUp => 0.80,
    GameSound.matchConnect => 0.50,
    GameSound.cardDrop => 0.40,
  };

  /// Priority score used to arbitrate simultaneous or overlapping events.
  int get priority => switch (this) {
    GameSound.levelUp || GameSound.perfectScore => 100,
    GameSound.quizComplete => 80,
    GameSound.streakMilestone => 70,
    GameSound.streak => 60,
    GameSound.correct || GameSound.wrong || GameSound.timeout => 50,
    GameSound.powerUp || GameSound.addTime || GameSound.skip => 40,
    GameSound.coinReward || GameSound.xpReward => 35,
    GameSound.matchConnect || GameSound.cardDrop => 30,
    GameSound.nextQuestion || GameSound.countdownTick => 20,
    GameSound.answerSelect || GameSound.buttonTap => 10,
  };
}
