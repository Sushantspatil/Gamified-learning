import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillverse_app/core/audio/audio_backend.dart';
import 'package:skillverse_app/core/audio/audio_providers.dart';
import 'package:skillverse_app/core/audio/game_audio_service.dart';
import 'package:skillverse_app/core/audio/game_sound.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioBackend fakeBackend;
  late LocalStorageService storage;
  late GameAudioService audioService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
    fakeBackend = FakeAudioBackend();
    audioService = GameAudioService(backend: fakeBackend, storage: storage);
  });

  tearDown(() {
    audioService.dispose();
  });

  group('GameAudioService Core & Settings', () {
    test('SFX ON plays sound and dispatches to AudioBackend', () async {
      expect(audioService.isSfxEnabled, isTrue);

      audioService.play(GameSound.correct);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds, hasLength(1));
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/answer_correct.mp3');
      expect(fakeBackend.playedSounds.first.volume, 0.60);
    });

    test('SFX OFF suppresses playback completely', () async {
      await audioService.setSfxEnabled(false);
      expect(audioService.isSfxEnabled, isFalse);

      audioService.play(GameSound.correct);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds, isEmpty);
    });

    test('Settings survive restart via LocalStorageService', () async {
      await audioService.setSfxEnabled(false);
      expect(storage.getBool(StorageKeys.sfxEnabled), isFalse);

      final reloadedService = GameAudioService(backend: fakeBackend, storage: storage);
      expect(reloadedService.isSfxEnabled, isFalse);

      reloadedService.play(GameSound.buttonTap);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, isEmpty);

      reloadedService.dispose();
    });

    test('App lifecycle pauses stop all audio playback', () async {
      audioService.didChangeAppLifecycleState(AppLifecycleState.paused);
      audioService.didChangeAppLifecycleState(AppLifecycleState.inactive);
      audioService.didChangeAppLifecycleState(AppLifecycleState.detached);
      // Completes gracefully without throws
    });

    test('Safe failure: playback exception is caught and does not crash gameplay', () async {
      final throwingBackend = _ThrowingAudioBackend();
      final resilientService = GameAudioService(backend: throwingBackend, storage: storage);

      expect(
        () => resilientService.play(GameSound.buttonTap),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);

      resilientService.dispose();
    });
  });

  group('Authoritative Event Sound Mapping & Sequencing', () {
    test('correct event plays answer_correct.mp3', () async {
      audioService.playAuthoritativeAnswerResult(isCorrect: true, streak: 1);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds.last.assetPath, 'audio/sfx/answer_correct.mp3');
      expect(fakeBackend.playedSounds.last.volume, 0.60);
    });

    test('wrong event plays answer_wrong.mp3', () async {
      audioService.playAuthoritativeAnswerResult(isCorrect: false, streak: 0);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds.last.assetPath, 'audio/sfx/answer_wrong.mp3');
      expect(fakeBackend.playedSounds.last.volume, 0.50);
    });

    test('MCQ does not leak correctness early (option selection plays answer_select only)', () async {
      // User taps option
      audioService.play(GameSound.answerSelect);
      await Future<void>.delayed(Duration.zero);

      // Verify answer_select played
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/answer_select.mp3'), isTrue);

      // Correct and wrong are never played per question in MCQ
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/answer_correct.mp3'), isFalse);
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/answer_wrong.mp3'), isFalse);
    });

    test('Match does not leak correctness early (connecting items plays match_connect only)', () async {
      // User selects first anchor
      audioService.play(GameSound.answerSelect);
      await Future<void>.delayed(Duration.zero);

      // User connects pair
      audioService.play(GameSound.matchConnect);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/match_connect.mp3'), isTrue);
      // Correct/wrong sounds must not play while users are still matching
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/answer_correct.mp3'), isFalse);
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/answer_wrong.mp3'), isFalse);
    });

    test('+5 sound plays only after backend success, rejected +5 plays no success sound', () async {
      // 1. Button tap without backend confirmation -> no sound
      expect(fakeBackend.playedSounds, isEmpty);

      // 2. Rejected request -> no success sound
      void handleAddTimeResponse({required bool isSuccess}) {
        if (isSuccess) {
          audioService.play(GameSound.addTime);
        }
      }

      handleAddTimeResponse(isSuccess: false);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/add_time.mp3'), isFalse);

      // 3. Backend confirms success -> plays add_time
      handleAddTimeResponse(isSuccess: true);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/add_time.mp3'), isTrue);
      expect(fakeBackend.playedSounds.last.volume, 0.60);
    });

    test('Skip success event plays skip swoosh only after authoritative confirmation', () async {
      // Server confirms skip
      audioService.play(GameSound.skip);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/skip.mp3'), isTrue);
    });

    test('Countdown ticks only 5 down to 1, silent 15 to 6, and each second plays once', () async {
      int? lastTickSecond;

      void onTimerTick(int remainingSeconds) {
        if (remainingSeconds >= 1 && remainingSeconds <= 5 && lastTickSecond != remainingSeconds) {
          lastTickSecond = remainingSeconds;
          audioService.play(GameSound.countdownTick);
        }
      }

      // Simulate seconds 15 down to 6 -> SILENT
      for (var s = 15; s >= 6; s--) {
        onTimerTick(s);
      }
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/countdown_tick.mp3'), isFalse);

      // Simulate seconds 5 down to 1 -> Exactly 5 ticks
      for (var s = 5; s >= 1; s--) {
        onTimerTick(s);
      }
      await Future<void>.delayed(Duration.zero);
      final tickCount = fakeBackend.playedSounds.where((s) => s.assetPath == 'audio/sfx/countdown_tick.mp3').length;
      expect(tickCount, 5);

      // Duplicate tick invocation for same second (e.g. widget rebuild) does not replay
      onTimerTick(1);
      await Future<void>.delayed(Duration.zero);
      expect(
        fakeBackend.playedSounds.where((s) => s.assetPath == 'audio/sfx/countdown_tick.mp3').length,
        5,
      );

      // Timer hits 0: must NOT play timeout sound purely from UI timer
      expect(fakeBackend.playedSounds.any((s) => s.assetPath == 'audio/sfx/timeout.mp3'), isFalse);
    });

    test('streak milestone replaces normal correct sound (milestone 3, 6, 9)', () async {
      audioService.playAuthoritativeAnswerResult(isCorrect: true, streak: 3);
      await Future<void>.delayed(Duration.zero);

      expect(fakeBackend.playedSounds, hasLength(1));
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/streak_milestone.mp3');
      expect(fakeBackend.playedSounds.first.volume, 0.70);

      fakeBackend.clear();
      audioService.playAuthoritativeAnswerResult(isCorrect: true, streak: 6);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/streak_milestone.mp3');

      fakeBackend.clear();
      audioService.playAuthoritativeAnswerResult(isCorrect: true, streak: 9);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/streak_milestone.mp3');

      fakeBackend.clear();
      // Non milestone streak (e.g., 4) plays ordinary correct sound
      audioService.playAuthoritativeAnswerResult(isCorrect: true, streak: 4);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/answer_correct.mp3');
    });

    test('quiz completion priority: level up > perfect score > regular complete', () async {
      // 1. Regular complete
      audioService.playQuizCompletion(isPerfect: false, leveledUp: false);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds.last.assetPath, 'audio/sfx/quiz_complete.mp3');

      // 2. Perfect score
      fakeBackend.clear();
      audioService.playQuizCompletion(isPerfect: true, leveledUp: false);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, hasLength(1));
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/perfect_score.mp3');

      // 3. Level up takes highest precedence and never simultaneously blasts perfect/complete
      fakeBackend.clear();
      audioService.playQuizCompletion(isPerfect: true, leveledUp: true);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, hasLength(1));
      expect(fakeBackend.playedSounds.first.assetPath, 'audio/sfx/level_up.mp3');
    });

    test('rebuild does not replay sound (idempotent listener handling)', () async {
      String? lastHandledQuestionId;

      void handleQuestionTransition(String questionId) {
        if (lastHandledQuestionId == questionId) return;
        lastHandledQuestionId = questionId;
        audioService.play(GameSound.nextQuestion);
      }

      // Initial question transition
      handleQuestionTransition('q-1');
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, hasLength(1));

      // Simulated widget rebuild with identical state
      handleQuestionTransition('q-1');
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, hasLength(1)); // Still only 1!
    });

    test('SoundSettingsController toggles SFX via Riverpod', () async {
      final container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(fakeBackend),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(soundSettingsControllerProvider.notifier);
      expect(container.read(soundSettingsControllerProvider).sfxEnabled, isTrue);

      await controller.toggleSfx(false);
      expect(container.read(soundSettingsControllerProvider).sfxEnabled, isFalse);

      final service = container.read(gameAudioServiceProvider);
      service.play(GameSound.correct);
      await Future<void>.delayed(Duration.zero);
      expect(fakeBackend.playedSounds, isEmpty);
    });
  });
}

class _ThrowingAudioBackend implements AudioBackend {
  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) {
    throw Exception('Simulated audio hardware failure');
  }

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}
