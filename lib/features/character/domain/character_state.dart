/// Visual/behavioural states of the host character.
enum CharacterState {
  idle,
  intro,
  presenting,
  thinking,
  hurry,
  correct,
  wrong,
  timeout,
  streak,
  win,
  lose;

  /// Higher wins when states compete:
  /// result* > timeout > hurry > thinking > intro > presenting > idle.
  int get priority => switch (this) {
    idle => 0,
    intro => 2,
    presenting => 1,
    thinking => 3,
    hurry => 4,
    timeout => 5,
    correct || wrong => 6,
    streak => 7,
    win || lose => 8,
  };

  /// One-shot states play once and then hand back to the baseline state.
  bool get isOneShot => switch (this) {
    intro || correct || wrong || timeout || streak => true,
    _ => false,
  };

  /// Game-over states stay until the controller is reset.
  bool get isTerminal => this == win || this == lose;
}
