import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';
import 'audio_backend.dart';
import 'game_audio_service.dart';
import 'sound_settings_state.dart';

/// Provides the underlying [AudioBackend]. Overridable in tests with [FakeAudioBackend].
final audioBackendProvider = Provider<AudioBackend>((ref) {
  return AudioplayerBackend();
});

/// Central singleton provider for [GameAudioService].
final gameAudioServiceProvider = Provider<GameAudioService>((ref) {
  final backend = ref.watch(audioBackendProvider);
  LocalStorageService? storage;
  try {
    storage = ref.watch(localStorageServiceProvider);
  } catch (_) {
    storage = null;
  }
  final service = GameAudioService(backend: backend, storage: storage);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Controller managing persistent sound settings.
class SoundSettingsController extends StateNotifier<SoundSettingsState> {
  final GameAudioService _audioService;

  SoundSettingsController({
    LocalStorageService? storage,
    required GameAudioService audioService,
  })  : _audioService = audioService,
        super(
          SoundSettingsState(
            sfxEnabled: storage?.getBool(StorageKeys.sfxEnabled) ?? true,
            musicEnabled: storage?.getBool(StorageKeys.musicEnabled) ?? true,
          ),
        );

  Future<void> toggleSfx(bool enabled) async {
    state = state.copyWith(sfxEnabled: enabled);
    await _audioService.setSfxEnabled(enabled);
  }

  Future<void> toggleMusic(bool enabled) async {
    state = state.copyWith(musicEnabled: enabled);
    await _audioService.setMusicEnabled(enabled);
  }
}

/// Provider for sound settings reactive state.
final soundSettingsControllerProvider =
    StateNotifierProvider<SoundSettingsController, SoundSettingsState>((ref) {
  LocalStorageService? storage;
  try {
    storage = ref.watch(localStorageServiceProvider);
  } catch (_) {
    storage = null;
  }
  final audioService = ref.watch(gameAudioServiceProvider);
  return SoundSettingsController(
    storage: storage,
    audioService: audioService,
  );
});
