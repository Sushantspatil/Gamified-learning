/// Inputs to the character. Game modes translate their own state into these
/// through a small adapter; the character knows nothing else about the game.
sealed class CharacterEvent {
  const CharacterEvent();

  const factory CharacterEvent.gameStarted() = GameStarted;
  const factory CharacterEvent.questionShown() = QuestionShown;
  const factory CharacterEvent.timerTick(double remainingFraction) = TimerTick;
  const factory CharacterEvent.answerSubmitted() = AnswerSubmitted;
  const factory CharacterEvent.resultCorrect() = ResultCorrect;
  const factory CharacterEvent.resultWrong() = ResultWrong;
  const factory CharacterEvent.timeExpired() = TimeExpired;
  const factory CharacterEvent.streakReached(int count) = StreakReached;
  const factory CharacterEvent.gameEnded({required bool won}) = GameEnded;
}

class GameStarted extends CharacterEvent {
  const GameStarted();
}

class QuestionShown extends CharacterEvent {
  const QuestionShown();
}

/// [remainingFraction] is 1.0 (full) .. 0.0 (expired).
class TimerTick extends CharacterEvent {
  final double remainingFraction;
  const TimerTick(this.remainingFraction);
}

class AnswerSubmitted extends CharacterEvent {
  const AnswerSubmitted();
}

class ResultCorrect extends CharacterEvent {
  const ResultCorrect();
}

class ResultWrong extends CharacterEvent {
  const ResultWrong();
}

class TimeExpired extends CharacterEvent {
  const TimeExpired();
}

class StreakReached extends CharacterEvent {
  final int count;
  const StreakReached(this.count);
}

class GameEnded extends CharacterEvent {
  final bool won;
  const GameEnded({required this.won});
}
