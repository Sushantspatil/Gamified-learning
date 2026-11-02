import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/character/application/character_controller.dart';
import 'package:skillverse_app/features/character/domain/character_event.dart';
import 'package:skillverse_app/features/character/domain/character_state.dart';
import 'package:skillverse_app/features/character/domain/character_strings.dart';

/// Manual clock so tests control exactly when timers fire.
class _ManualScheduler implements CharacterScheduler {
  final List<_Pending> _pending = [];
  Duration now = Duration.zero;

  int get pendingCount => _pending.length;

  @override
  CancelTimer after(Duration delay, void Function() callback) {
    final entry = _Pending(now + delay, callback);
    _pending.add(entry);
    return () => _pending.remove(entry);
  }

  void advance(Duration by) {
    final target = now + by;
    while (true) {
      _pending.sort((a, b) => a.at.compareTo(b.at));
      final due = _pending.where((p) => p.at <= target).toList();
      if (due.isEmpty) break;
      final next = due.first;
      _pending.remove(next);
      now = next.at;
      next.callback();
    }
    now = target;
  }
}

class _Pending {
  final Duration at;
  final void Function() callback;
  _Pending(this.at, this.callback);
}

void main() {
  late _ManualScheduler clock;
  late CharacterController c;

  setUp(() {
    clock = _ManualScheduler();
    c = CharacterController(scheduler: clock, random: Random(1));
    addTearDown(c.dispose);
  });

  CharacterState state() => c.state.value;
  void ms(int n) => clock.advance(Duration(milliseconds: n));

  group('priority', () {
    test('priority order matches the spec', () {
      const ordered = [
        CharacterState.idle,
        CharacterState.presenting,
        CharacterState.thinking,
        CharacterState.hurry,
        CharacterState.timeout,
        CharacterState.correct,
        CharacterState.streak,
        CharacterState.win,
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i].priority, greaterThan(ordered[i - 1].priority));
      }
      expect(CharacterState.correct.priority, CharacterState.wrong.priority);
      expect(
        CharacterState.intro.priority,
        greaterThan(CharacterState.presenting.priority),
      );
    });

    test(
      'result beats hurry, then falls back to idle (not stuck hurrying)',
      () {
        c.send(const CharacterEvent.questionShown());
        c.send(const CharacterEvent.timerTick(0.1));
        expect(state(), CharacterState.hurry);

        c.send(const CharacterEvent.resultCorrect());
        expect(state(), CharacterState.correct);

        ms(CharacterController.resultDuration.inMilliseconds);
        expect(state(), CharacterState.idle);
      },
    );

    test('lower priority one-shot cannot interrupt a higher one', () {
      c.send(const CharacterEvent.resultCorrect());
      c.send(const CharacterEvent.timeExpired()); // timeout < correct
      expect(state(), CharacterState.correct);
      ms(2000);
      expect(state(), CharacterState.idle);
    });

    test('higher priority one-shot interrupts a lower one', () {
      c.send(const CharacterEvent.timeExpired());
      expect(state(), CharacterState.timeout);
      c.send(const CharacterEvent.resultWrong());
      expect(state(), CharacterState.wrong);
    });

    test('streak replaces correct; streaks below 3 are ignored', () {
      c.send(const CharacterEvent.streakReached(2));
      expect(state(), CharacterState.idle);
      c.send(const CharacterEvent.resultCorrect());
      c.send(const CharacterEvent.streakReached(5));
      expect(state(), CharacterState.streak);
      expect(c.streakLevel, 2);
      c.send(const CharacterEvent.streakReached(10));
      expect(c.streakLevel, 3);
    });

    test('intro is not hidden by presenting but yields to thinking', () {
      c.send(const CharacterEvent.gameStarted());
      expect(state(), CharacterState.intro);
      c.send(const CharacterEvent.questionShown());
      expect(state(), CharacterState.intro);
      ms(CharacterController.introDuration.inMilliseconds);
      // Presenting already settled to idle while the intro played.
      expect(state(), CharacterState.idle);
    });
  });

  group('auto-return and no stuck states', () {
    test('presenting settles to idle without a timer', () {
      c.send(const CharacterEvent.questionShown());
      expect(state(), CharacterState.presenting);
      ms(CharacterController.presentingSettle.inMilliseconds);
      expect(state(), CharacterState.idle);
    });

    test('presenting settles to thinking when a timer is running', () {
      c.send(const CharacterEvent.questionShown());
      c.send(const CharacterEvent.timerTick(0.9));
      expect(state(), CharacterState.thinking);
      ms(5000);
      expect(state(), CharacterState.thinking);
    });

    test('hurry starts at 25% and scales intensity as time runs out', () {
      c.send(const CharacterEvent.timerTick(0.5));
      expect(state(), CharacterState.thinking);
      c.send(const CharacterEvent.timerTick(0.25));
      expect(state(), CharacterState.hurry);
      final early = c.intensity.value;
      c.send(const CharacterEvent.timerTick(0.05));
      expect(c.intensity.value, greaterThan(early));
      c.send(const CharacterEvent.timerTick(0.8)); // timer reset
      expect(state(), CharacterState.thinking);
      expect(c.intensity.value, 0);
    });

    test('every one-shot returns to a baseline on its own', () {
      for (final event in const [
        CharacterEvent.gameStarted(),
        CharacterEvent.resultCorrect(),
        CharacterEvent.resultWrong(),
        CharacterEvent.timeExpired(),
        CharacterEvent.streakReached(10),
      ]) {
        c.reset();
        c.send(event);
        expect(state().isOneShot, isTrue, reason: '$event');
        ms(10000);
        expect(state(), CharacterState.idle, reason: '$event');
        expect(clock.pendingCount, 0, reason: 'no leaked timers for $event');
      }
    });

    test('game end is terminal until reset; late events cannot revive it', () {
      c.send(const CharacterEvent.gameEnded(won: true));
      expect(state(), CharacterState.win);
      c.send(const CharacterEvent.questionShown());
      c.send(const CharacterEvent.resultWrong());
      c.send(const CharacterEvent.timerTick(0.1));
      ms(10000);
      expect(state(), CharacterState.win);

      c.reset();
      expect(state(), CharacterState.idle);
      expect(c.currentSpeech, isNull);
    });

    test('lose is a distinct, calm terminal state', () {
      c.send(const CharacterEvent.gameEnded(won: false));
      expect(state(), CharacterState.lose);
    });

    test('reset clears timers and speech (screen exit / reconnect)', () {
      c.send(const CharacterEvent.timerTick(0.1));
      c.send(const CharacterEvent.resultWrong());
      c.reset();
      expect(state(), CharacterState.idle);
      expect(clock.pendingCount, 0);
      expect(c.currentSpeech, isNull);
      expect(c.intensity.value, 0);
    });

    test('dispose cancels timers and ignores further events', () {
      c.send(const CharacterEvent.resultCorrect());
      c.dispose();
      expect(clock.pendingCount, 0);
      c.send(const CharacterEvent.resultWrong()); // must not throw
      expect(c.isDisposed, isTrue);
    });
  });

  group('rapid events', () {
    test('a burst of events ends in a sane state with no leaked timers', () {
      for (var i = 0; i < 50; i++) {
        c.send(const CharacterEvent.questionShown());
        c.send(const CharacterEvent.answerSubmitted());
        c.send(
          i.isEven
              ? const CharacterEvent.resultCorrect()
              : const CharacterEvent.resultWrong(),
        );
        c.send(CharacterEvent.timerTick((i % 10) / 10 + 0.05));
      }
      ms(60000);
      expect(state().isTerminal, isFalse);
      expect(clock.pendingCount, 0);
    });

    test('repeated correct restarts the reaction (pulse) without stacking', () {
      c.send(const CharacterEvent.resultCorrect());
      final first = c.pulse.value;
      ms(500);
      c.send(const CharacterEvent.resultCorrect());
      expect(c.pulse.value, greaterThan(first));
      // Timer was restarted: 900 ms after the second event still correct.
      ms(900);
      expect(state(), CharacterState.correct);
      ms(600);
      expect(state(), CharacterState.idle);
    });

    test('answer submitted after hurry returns to calm thinking', () {
      c.send(const CharacterEvent.timerTick(0.1));
      c.send(const CharacterEvent.answerSubmitted());
      expect(state(), CharacterState.thinking);
      expect(c.intensity.value, 0);
    });
  });

  group('speech', () {
    test('a line is shown for a reaction and auto-hides', () {
      final seen = <String?>[];
      final sub = c.speech.listen(seen.add);
      addTearDown(sub.cancel);

      c.send(const CharacterEvent.resultCorrect());
      expect(
        CharacterStrings.lines[SpeechTopic.correct],
        contains(c.currentSpeech),
      );
      ms(CharacterController.speechDuration.inMilliseconds);
      expect(c.currentSpeech, isNull);
      expect(seen.last, isNull);
    });

    test('lines are short (max ~6 words) and each pool has variety', () {
      for (final pool in CharacterStrings.lines.values) {
        expect(pool.length, greaterThanOrEqualTo(3));
        for (final line in pool) {
          expect(line.split(' ').length, lessThanOrEqualTo(6), reason: line);
        }
      }
    });

    test('never repeats the same line twice in a row for a topic', () {
      String? previous;
      for (var i = 0; i < 40; i++) {
        c.send(const CharacterEvent.resultWrong());
        final line = c.currentSpeech;
        expect(line, isNot(previous));
        previous = line;
        ms(3000);
      }
    });

    test('lower-priority reaction stays silent while a higher one plays', () {
      c.send(const CharacterEvent.resultCorrect());
      final line = c.currentSpeech;
      c.send(const CharacterEvent.timeExpired());
      expect(c.currentSpeech, line);
    });

    test('MCQ-style neutral flow produces no verdict speech', () {
      final lines = <String?>[];
      c.speech.listen(lines.add);
      c.send(const CharacterEvent.questionShown());
      c.send(const CharacterEvent.answerSubmitted());
      expect(lines.whereType<String>(), isEmpty);
    });
  });
}
