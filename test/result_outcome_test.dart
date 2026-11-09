import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/quiz/domain/result_outcome.dart';

void main() {
  group('a normal game', () {
    test('90 percent and over is brilliant', () {
      for (final correct in [9, 10]) {
        final o = outcomeFor(endedEarly: false, correct: correct, total: 10);
        expect(o.headline, 'Brilliant!', reason: '$correct of 10');
        expect(o.subdued, isFalse);
        expect(o.detail, isNull);
      }
    });

    test('60 to 89 percent is great', () {
      for (final correct in [6, 7, 8]) {
        expect(
          outcomeFor(endedEarly: false, correct: correct, total: 10).headline,
          'Great job!',
          reason: '$correct of 10',
        );
      }
    });

    test('anything lower with something right is good effort', () {
      for (final correct in [1, 3, 5]) {
        final o = outcomeFor(endedEarly: false, correct: correct, total: 10);
        expect(o.headline, 'Good effort!', reason: '$correct of 10');
        expect(o.subdued, isFalse);
      }
    });

    test('nothing right is encouraging and calm', () {
      final o = outcomeFor(endedEarly: false, correct: 0, total: 10);
      expect(o.headline, 'Keep going!');
      expect(o.subdued, isTrue);
      expect(o.detail, isNotNull);
    });

    test('an empty game does not divide by zero', () {
      final o = outcomeFor(endedEarly: false, correct: 0, total: 0);
      expect(o.headline, 'Keep going!');
      expect(o.subdued, isTrue);
    });

    test('works for other lengths', () {
      expect(
        outcomeFor(endedEarly: false, correct: 3, total: 5).headline,
        'Great job!',
      ); // 60%
      expect(
        outcomeFor(endedEarly: false, correct: 2, total: 5).headline,
        'Good effort!',
      ); // 40%
      expect(
        outcomeFor(endedEarly: false, correct: 5, total: 5).headline,
        'Brilliant!',
      );
    });
  });

  group('Sudden Death', () {
    test('says how many were right', () {
      final o = outcomeFor(endedEarly: true, correct: 7, total: 8);
      expect(o.headline, 'Nice run!');
      expect(o.detail, 'You got 7 right before it ended');
      expect(o.subdued, isFalse);
    });

    test('the headline grows with the run', () {
      String h(int c) =>
          outcomeFor(endedEarly: true, correct: c, total: c + 1).headline;
      expect(h(0), 'Tough one!');
      expect(h(1), 'Good try!');
      expect(h(4), 'Good try!');
      expect(h(5), 'Nice run!');
      expect(h(9), 'Nice run!');
      expect(h(10), 'Incredible run!');
    });

    test('an immediate loss is gentle and calm', () {
      final o = outcomeFor(endedEarly: true, correct: 0, total: 1);
      expect(o.subdued, isTrue);
      expect(o.detail, contains('Go again'));
    });
  });
}
