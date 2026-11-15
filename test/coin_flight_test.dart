import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/shared/widgets/coin_flight.dart';

class _Harness extends StatefulWidget {
  final GlobalKey from;
  final GlobalKey to;
  final bool showTo;
  final ValueChanged<OverlayEntry?> onFlight;

  const _Harness({
    required this.from,
    required this.to,
    required this.onFlight,
    this.showTo = true,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(key: widget.from, width: 40, height: 40),
        if (widget.showTo) SizedBox(key: widget.to, width: 60, height: 30),
        TextButton(
          key: const Key('fly'),
          onPressed: () => widget.onFlight(
            flyCoins(context, from: widget.from, to: widget.to),
          ),
          child: const Text('fly'),
        ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required ValueChanged<OverlayEntry?> onFlight,
  bool showTo = true,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: _Harness(
            from: GlobalKey(),
            to: GlobalKey(),
            showTo: showTo,
            onFlight: onFlight,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('flyCoins', () {
    testWidgets('puts coins on screen and cleans up when they have landed', (
      tester,
    ) async {
      OverlayEntry? flight;
      await _pump(tester, onFlight: (e) => flight = e);

      await tester.tap(find.byKey(const Key('fly')));
      await tester.pump();
      expect(flight, isNotNull);
      expect(find.byKey(const Key('coin_flight')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('coin_flight')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coin_flight')), findsNothing);
      expect(flight!.mounted, isFalse);
    });

    testWidgets('the coins do not block taps on the screen below', (
      tester,
    ) async {
      await _pump(tester, onFlight: (_) {});
      await tester.tap(find.byKey(const Key('fly')));
      await tester.pump(const Duration(milliseconds: 300));

      final inFlight = find.byKey(const Key('coin_flight'));
      expect(inFlight, findsOneWidget);
      final ignoring = tester.widget<IgnorePointer>(
        find
            .descendant(of: inFlight, matching: find.byType(IgnorePointer))
            .first,
      );
      expect(ignoring.ignoring, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('can be cut short', (tester) async {
      OverlayEntry? flight;
      await _pump(tester, onFlight: (e) => flight = e);

      await tester.tap(find.byKey(const Key('fly')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('coin_flight')), findsOneWidget);

      flight!.remove();
      await tester.pump();
      expect(find.byKey(const Key('coin_flight')), findsNothing);
      // Nothing left running that could fail the test later.
      await tester.pumpAndSettle();
    });

    testWidgets('does nothing when the target is not on screen', (
      tester,
    ) async {
      var called = false;
      OverlayEntry? flight;
      await _pump(
        tester,
        showTo: false,
        onFlight: (e) {
          called = true;
          flight = e;
        },
      );

      await tester.tap(find.byKey(const Key('fly')));
      await tester.pump();
      expect(called, isTrue);
      expect(flight, isNull);
      expect(find.byKey(const Key('coin_flight')), findsNothing);
    });

    testWidgets('does nothing when the player wants reduced motion', (
      tester,
    ) async {
      OverlayEntry? flight;
      var called = false;
      await _pump(
        tester,
        reduceMotion: true,
        onFlight: (e) {
          called = true;
          flight = e;
        },
      );

      await tester.tap(find.byKey(const Key('fly')));
      await tester.pump();
      expect(called, isTrue);
      expect(flight, isNull);
      expect(find.byKey(const Key('coin_flight')), findsNothing);
    });
  });
}
