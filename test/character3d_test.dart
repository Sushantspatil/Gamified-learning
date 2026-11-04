import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/character3d/presentation/character_3d_view.dart';
import 'package:skillverse_app/features/character3d/presentation/equipped_cosmetics.dart';
import 'package:skillverse_app/features/rewards/application/rewards_controller.dart';
import 'package:skillverse_app/features/character3d/presentation/result_mascot.dart';
import 'package:skillverse_app/features/dashboard/presentation/widgets/mascot_card.dart';

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  _moreTests();
  group('3D character is optional', () {
    testWidgets('without a WebView the fallback shows and nothing throws', (
      tester,
    ) async {
      await _show(
        tester,
        const Character3dView(
          width: 120,
          height: 150,
          fallback: Text('fallback'),
        ),
      );
      expect(find.text('fallback'), findsOneWidget);
      expect(
        tester.getSize(find.byType(Character3dView)),
        const Size(120, 150),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('state and framing changes are accepted while unavailable', (
      tester,
    ) async {
      Widget view(Character3dState s) => Character3dView(
        width: 100,
        height: 100,
        state: s,
        fallback: const Text('fallback'),
      );
      await _show(tester, view(Character3dState.walk));
      await _show(tester, view(Character3dState.idle));
      expect(find.text('fallback'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strip controller commands are harmless without 3D', (
      tester,
    ) async {
      final controller = Character3dController();
      controller.enter(); // before any view exists
      await _show(
        tester,
        Character3dView(
          width: 300,
          height: 120,
          framing: Character3dFraming.strip,
          controller: controller,
          fallback: const Text('fallback'),
        ),
      );
      controller
        ..enter()
        ..hop()
        ..exit();
      await tester.pump();
      expect(find.text('fallback'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The view going away detaches it; later commands still do nothing.
      await tester.pumpWidget(const SizedBox());
      controller
        ..enter()
        ..hop();
      expect(tester.takeException(), isNull);
    });

    testWidgets('results mascot shows the trophy when 3D is unavailable', (
      tester,
    ) async {
      await _show(
        tester,
        const ResultMascot(
          unsuccessful: false,
          accuracy: 1,
          trophy: Text('trophy'),
        ),
      );
      expect(find.text('trophy'), findsOneWidget);
      expect(tester.getSize(find.byType(ResultMascot)).height, 150);
    });

    testWidgets('dashboard card greets the learner and fits a small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136); // 320 x 568
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: MascotCard(displayName: 'Asha Rao', streak: 4),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text("Let's go, Asha!"), findsOneWidget);
      expect(find.textContaining('4-day streak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new learner with no streak gets a starting prompt', (
      tester,
    ) async {
      await _show(tester, const MascotCard(displayName: '', streak: 0));
      expect(find.text('Ready to learn?'), findsOneWidget);
      expect(find.textContaining('start your streak'), findsOneWidget);
    });
  });

  test('the bundled page exists and carries the model and the bridge', () {
    final page = File(Character3dView.assetPath);
    expect(page.existsSync(), isTrue, reason: 'run npm run build:embed');
    final text = page.readAsStringSync();
    expect(text, contains('window.__CHARACTER_GLB_B64'));
    expect(text, contains('CharacterBridge'));
    expect(text, contains('CharacterEmbed'));
    expect(text.length, greaterThan(1000000)); // script + model inside
  });
}

void _moreTests() {
  group('character reactions and extras', () {
    test(
      'results: cheer for >= 80%, applause for 50-79%, sad below or lost',
      () {
        Character3dAction r(double a, {bool lost = false}) =>
            ResultMascot.reaction(unsuccessful: lost, accuracy: a);
        expect(r(1), Character3dAction.cheer);
        expect(r(0.8), Character3dAction.cheer);
        expect(r(0.79), Character3dAction.clap);
        expect(r(0.5), Character3dAction.clap);
        expect(r(0.49), Character3dAction.sad);
        expect(r(0.9, lost: true), Character3dAction.sad);
      },
    );

    test('shop ids become the names the 3D page knows', () {
      final c = Character3dCosmetics.fromShopIds(
        avatarId: 'avatar-champion',
        frameId: 'frame-gold',
      );
      expect(c.avatar, 'champion');
      expect(c.frame, 'gold');
      expect(Character3dCosmetics.fromShopIds().avatar, isNull);
      expect(c, const Character3dCosmetics(avatar: 'champion', frame: 'gold'));
      expect(c.toJson(), '{"avatar":"champion","frame":"gold"}');
    });

    test('the dashboard line follows what matters most', () {
      String m({int streak = 0, bool chest = false, bool spin = false}) =>
          MascotCard.messageFor(
            streak: streak,
            chestReady: chest,
            canSpin: spin,
          );
      expect(m(streak: 5, chest: true, spin: true), contains('chest'));
      expect(m(streak: 5, spin: true), contains('spin'));
      expect(m(streak: 5), contains('5-day streak'));
      expect(m(), contains('start your streak'));
    });

    testWidgets('equipped items come from the rewards state', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      // Own and equip a cosmetic of each kind.
      final rewards = container.read(rewardsProvider.notifier);
      container.read(rewardsProvider); // build
      rewards.purchase('frame-bronze'); // 50 coins
      rewards.equip('frame-bronze');

      late Character3dCosmetics seen;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                seen = equippedCosmetics(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen.frame, 'bronze');
      expect(seen.avatar, isNull);

      // Without a provider scope nothing is equipped and nothing throws.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = equippedCosmetics(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, Character3dCosmetics.none);
    });

    testWidgets('prewarm is harmless where WebView is unsupported', (
      tester,
    ) async {
      Character3dView.prewarm();
      Character3dView.prewarm();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the controller reports unavailable when 3D cannot run', (
      tester,
    ) async {
      final controller = Character3dController();
      addTearDown(controller.dispose);
      await _show(
        tester,
        Character3dView(
          width: 100,
          height: 100,
          controller: controller,
          fallback: const Text('fallback'),
        ),
      );
      await tester.pump();
      expect(controller.status.value, Character3dStatus.unavailable);
    });

    test('the poster is bundled', () {
      expect(File(Character3dView.posterAsset).existsSync(), isTrue);
    });
  });
}
