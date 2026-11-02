import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/character_event.dart';
import '../domain/character_state.dart';
import '../domain/character_strings.dart';

typedef CancelTimer = void Function();

/// Seam over timers so the state machine can be tested with manual time.
abstract interface class CharacterScheduler {
  CancelTimer after(Duration delay, void Function() callback);
}

class TimerCharacterScheduler implements CharacterScheduler {
  const TimerCharacterScheduler();

  @override
  CancelTimer after(Duration delay, void Function() callback) {
    final timer = Timer(delay, callback);
    return timer.cancel;
  }
}

/// Maps [CharacterEvent]s to a [CharacterState] and a speech line.
///
/// Knows nothing about sockets, scoring or questions. Display rules:
/// * A terminal state (win/lose) sticks until [reset].
/// * A one-shot (intro, correct, wrong, timeout, streak) shows while it is
///   active if its priority is at least the baseline's; it then hands back to
///   the baseline (idle / presenting / thinking / hurry) on its own.
/// * A one-shot cannot be interrupted by a lower-priority one-shot.
class CharacterController {
  CharacterController({CharacterScheduler? scheduler, Random? random})
    : _scheduler = scheduler ?? const TimerCharacterScheduler(),
      _random = random ?? Random();

  static const Duration introDuration = Duration(milliseconds: 1600);
  static const Duration presentingSettle = Duration(milliseconds: 1000);
  static const Duration resultDuration = Duration(milliseconds: 1400);
  static const Duration timeoutDuration = Duration(milliseconds: 1600);
  static const Duration speechDuration = Duration(milliseconds: 1800);

  /// Below this remaining fraction the character is in a hurry.
  static const double hurryThreshold = 0.25;

  final CharacterScheduler _scheduler;
  final Random _random;

  final ValueNotifier<CharacterState> _state = ValueNotifier(
    CharacterState.idle,
  );
  final ValueNotifier<int> _pulse = ValueNotifier(0);
  final ValueNotifier<double> _intensity = ValueNotifier(0);
  final StreamController<String?> _speech = StreamController.broadcast(
    sync: true,
  );

  CharacterState _baseline = CharacterState.idle;
  CharacterState? _shot;
  CharacterState? _terminal;
  bool _timerActive = false;
  bool _disposed = false;
  int _streakLevel = 0;
  String? _currentSpeech;
  final Map<SpeechTopic, String> _lastLine = {};

  CancelTimer? _shotTimer;
  CancelTimer? _settleTimer;
  CancelTimer? _speechTimer;

  ValueListenable<CharacterState> get state => _state;

  /// Bumps every time a one-shot (re)starts, so the view can restart its
  /// animation even when the state value itself did not change.
  ValueListenable<int> get pulse => _pulse;

  /// 0..1, how urgent the hurry state is (grows as time runs out).
  ValueListenable<double> get intensity => _intensity;

  /// 0 (none), 1 (3+), 2 (5+), 3 (10+): scales the streak celebration.
  int get streakLevel => _streakLevel;

  Stream<String?> get speech => _speech.stream;
  String? get currentSpeech => _currentSpeech;
  bool get isDisposed => _disposed;

  void send(CharacterEvent event) {
    if (_disposed) return;
    switch (event) {
      case GameStarted():
        reset();
        _startShot(
          CharacterState.intro,
          introDuration,
          topic: SpeechTopic.intro,
        );
      case QuestionShown():
        if (_terminal != null) return;
        _timerActive = false;
        _intensity.value = 0;
        _baseline = CharacterState.presenting;
        _cancelSettle();
        _settleTimer = _scheduler.after(presentingSettle, () {
          _settleTimer = null;
          _baseline = _timerActive
              ? CharacterState.thinking
              : CharacterState.idle;
          _publish();
        });
        _publish();
      case TimerTick(:final remainingFraction):
        if (_terminal != null || remainingFraction <= 0) return;
        final fraction = remainingFraction.clamp(0.0, 1.0);
        _timerActive = true;
        _cancelSettle();
        final wasHurry = _baseline == CharacterState.hurry;
        if (fraction <= hurryThreshold) {
          _baseline = CharacterState.hurry;
          _intensity.value = (1 - fraction / hurryThreshold).clamp(0.0, 1.0);
          if (!wasHurry) _say(SpeechTopic.hurry);
        } else {
          _baseline = CharacterState.thinking;
          _intensity.value = 0;
        }
        _publish();
      case AnswerSubmitted():
        if (_terminal != null) return;
        _timerActive = false;
        _intensity.value = 0;
        _cancelSettle();
        _baseline = CharacterState.thinking;
        _publish();
      case ResultCorrect():
        _afterVerdict();
        _startShot(
          CharacterState.correct,
          resultDuration,
          topic: SpeechTopic.correct,
        );
      case ResultWrong():
        _afterVerdict();
        _startShot(
          CharacterState.wrong,
          resultDuration,
          topic: SpeechTopic.wrong,
        );
      case TimeExpired():
        _afterVerdict();
        _startShot(
          CharacterState.timeout,
          timeoutDuration,
          topic: SpeechTopic.timeout,
        );
      case StreakReached(:final count):
        if (count < 3) return;
        _streakLevel = count >= 10 ? 3 : (count >= 5 ? 2 : 1);
        _startShot(
          CharacterState.streak,
          Duration(milliseconds: 1800 + _streakLevel * 400),
          topic: count >= 10 ? SpeechTopic.streakBig : SpeechTopic.streak,
        );
      case GameEnded(:final won):
        _cancelAll();
        _shot = null;
        _timerActive = false;
        _intensity.value = 0;
        _terminal = won ? CharacterState.win : CharacterState.lose;
        _pulse.value++;
        _say(won ? SpeechTopic.win : SpeechTopic.lose);
        _publish();
    }
  }

  /// Back to a clean idle. Safe to call at any time (screen exit, reconnect).
  void reset() {
    if (_disposed) return;
    _cancelAll();
    _baseline = CharacterState.idle;
    _shot = null;
    _terminal = null;
    _timerActive = false;
    _streakLevel = 0;
    _intensity.value = 0;
    _setSpeech(null);
    _publish();
  }

  void dispose() {
    if (_disposed) return;
    _cancelAll();
    _disposed = true;
    _speech.close();
    _state.dispose();
    _pulse.dispose();
    _intensity.dispose();
  }

  // ---- internals ------------------------------------------------------

  void _afterVerdict() {
    // The verdict ends the timed phase; fall back to idle when it finishes.
    _timerActive = false;
    _intensity.value = 0;
    _cancelSettle();
    if (_baseline == CharacterState.hurry ||
        _baseline == CharacterState.thinking) {
      _baseline = CharacterState.idle;
    }
  }

  void _startShot(
    CharacterState shot,
    Duration duration, {
    required SpeechTopic topic,
  }) {
    if (_terminal != null) return;
    final active = _shot;
    if (active != null && active.priority > shot.priority) return;

    _shotTimer?.call();
    _shot = shot;
    _pulse.value++;
    _shotTimer = _scheduler.after(duration, () {
      _shotTimer = null;
      _shot = null;
      _publish();
    });
    if (shot.priority >= _baseline.priority) _say(topic);
    _publish();
  }

  void _publish() {
    if (_disposed) return;
    final shot = _shot;
    _state.value =
        _terminal ??
        ((shot != null && shot.priority >= _baseline.priority)
            ? shot
            : _baseline);
  }

  void _say(SpeechTopic topic) {
    final pool = CharacterStrings.lines[topic]!;
    final last = _lastLine[topic];
    final candidates = pool.where((line) => line != last).toList();
    final line = candidates[_random.nextInt(candidates.length)];
    _lastLine[topic] = line;
    _setSpeech(line);
    _speechTimer?.call();
    _speechTimer = _scheduler.after(speechDuration, () {
      _speechTimer = null;
      _setSpeech(null);
    });
  }

  void _setSpeech(String? line) {
    if (_disposed) return;
    _currentSpeech = line;
    _speech.add(line);
  }

  void _cancelSettle() {
    _settleTimer?.call();
    _settleTimer = null;
  }

  void _cancelAll() {
    _shotTimer?.call();
    _settleTimer?.call();
    _speechTimer?.call();
    _shotTimer = _settleTimer = _speechTimer = null;
  }
}
