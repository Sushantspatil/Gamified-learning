import '../application/character_controller.dart';
import '../domain/character_event.dart';

/// Translates MCQ play into [CharacterEvent]s. This is the only character
/// file that knows about a game mode; to support another mode, write another
/// adapter like this one.
///
/// MCQ answers are graded after the last question and the mode has no
/// timer, so this adapter deliberately takes no question, option or
/// correctness data: the character can only react neutrally and can never
/// leak the answer. It emits no timer or verdict events.
class McqCharacterAdapter {
  final CharacterController _character;

  const McqCharacterAdapter(this._character);

  /// A question appeared. The first one also starts the game (intro).
  void questionShown({required bool isFirst}) {
    if (isFirst) _character.send(const CharacterEvent.gameStarted());
    _character.send(const CharacterEvent.questionShown());
  }

  /// The student submitted an answer. On the last question the quiz is over;
  /// the character celebrates finishing, not a score (no verdict is known).
  void answerSubmitted({required bool isFinal}) {
    _character.send(const CharacterEvent.answerSubmitted());
    if (isFinal) _character.send(const CharacterEvent.gameEnded(won: true));
  }

  /// Screen is going away or the session was interrupted.
  void leave() => _character.reset();
}
