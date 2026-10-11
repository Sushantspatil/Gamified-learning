import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';

import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';
import 'audio_backend.dart';
import 'game_sound.dart';

/// Central production-ready game audio service.
///
/// Encapsulates all SFX triggers, settings persistence, app lifecycle management,
/// and priority-based sequencing. Ensures that sound playback never blocks gameplay.
class GameAudioService with WidgetsBindingObserver {
  final AudioBackend _backend;
  final LocalStorageService? _storage;

  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _isDisposed = false;

  GameAudioService({
    required AudioBackend backend,
    LocalStorageService? storage,
  })  : _backend = backend,
        _storage = storage {
    _loadSettings();
    WidgetsBinding.instance.addObserver(this);
  }

  void _loadSettings() {
    if (_storage != null) {
      _sfxEnabled = _storage.getBool(StorageKeys.sfxEnabled) ?? true;
      _musicEnabled = _storage.getBool(StorageKeys.musicEnabled) ?? true;
    }
  }

  /// Whether sound effects are currently enabled.
  bool get isSfxEnabled => _sfxEnabled;

  /// Whether background music is currently enabled (for future phases).
  bool get isMusicEnabled => _musicEnabled;

  /// Updates SFX enabled state and persists the preference.
  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    if (!enabled) {
      unawaited(_backend.stopAll());
    }
    await _storage?.setBool(StorageKeys.sfxEnabled, enabled);
  }

  /// Updates background music preference (prepared for future phases).
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    await _storage?.setBool(StorageKeys.musicEnabled, enabled);
  }

  /// Fire-and-forget SFX playback.
  ///
  /// Safe failure: if sound fails or asset is missing, gameplay continues uninterrupted.
  void play(GameSound sound, {double? volumeOverride}) {
    if (!_sfxEnabled || _isDisposed) return;
    unawaited(_playSafe(sound, volumeOverride: volumeOverride));
  }

  Future<void> _playSafe(GameSound sound, {double? volumeOverride}) async {
    try {
      final volume = volumeOverride ?? sound.defaultVolume;
      await _backend.playAsset(sound.assetPath, volume: volume);
    } catch (e, stack) {
      developer.log(
        'SFX playback ignored for ${sound.name}: $e',
        name: 'GameAudioService',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Plays appropriate completion sound adhering to priority rules:
  /// Level Up / Perfect Score > Standard Completion.
  /// Never simultaneously blasts multiple completion sounds.
  void playQuizCompletion({
    required bool isPerfect,
    required bool leveledUp,
  }) {
    if (leveledUp) {
      play(GameSound.levelUp);
    } else if (isPerfect) {
      play(GameSound.perfectScore);
    } else {
      play(GameSound.quizComplete);
    }
  }

  /// Plays authoritative answer result sound for Sudden Death or interactive modes:
  /// If the streak reaches a milestone (3, 6, 9), the milestone sound takes priority
  /// and replaces the ordinary correct sound for that answer.
  void playAuthoritativeAnswerResult({
    required bool isCorrect,
    required int streak,
  }) {
    if (isCorrect) {
      if (streak == 3 || streak == 6 || streak == 9) {
        play(GameSound.streakMilestone);
      } else {
        play(GameSound.correct);
      }
    } else {
      play(GameSound.wrong);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_backend.stopAll());
    }
  }

  /// Cleans up observer and backend handles.
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_backend.dispose());
  }
}
