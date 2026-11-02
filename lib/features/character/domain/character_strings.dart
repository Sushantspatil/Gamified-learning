/// Speech lines for the host character.
///
/// The app has no localization system yet, so every user-facing string lives
/// here (and only here) keyed by speech topic. Moving to ARB/intl later means
/// replacing this one map.
enum SpeechTopic {
  intro,
  correct,
  wrong,
  timeout,
  hurry,
  streak,
  streakBig,
  win,
  lose,
}

class CharacterStrings {
  CharacterStrings._();

  static const Map<SpeechTopic, List<String>> lines = {
    SpeechTopic.intro: ["Let's play!", 'Ready? Here we go!', 'Welcome back!'],
    SpeechTopic.correct: ['Nice one!', 'Spot on!', 'You got it!', 'Boom!'],
    SpeechTopic.wrong: [
      'Close one!',
      "Next one's yours!",
      'Shake it off!',
      'Almost there!',
    ],
    SpeechTopic.timeout: [
      'Too slow, keep going!',
      'Time ran out!',
      'Next one, quick!',
    ],
    SpeechTopic.hurry: ['Tick tock!', 'Quick, quick!', 'Clock is ticking!'],
    SpeechTopic.streak: ["You're on fire!", 'Keep it rolling!', 'Hot streak!'],
    SpeechTopic.streakBig: ['Unstoppable!', 'Legendary run!', 'Crazy streak!'],
    SpeechTopic.win: ['Nice run!', "That's a wrap!", 'Well played!'],
    SpeechTopic.lose: ['Good effort!', "You'll get it next time!", 'Go again!'],
  };
}
