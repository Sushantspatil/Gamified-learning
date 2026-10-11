import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';

/// Contract for underlying audio playback implementations.
/// Decoupling the backend enables 100% headless unit/widget tests without native audio drivers.
abstract class AudioBackend {
  /// Plays the audio file specified by [assetPath] relative to the assets bundle.
  Future<void> playAsset(String assetPath, {double volume = 1.0});

  /// Stops all currently playing audio clips immediately.
  Future<void> stopAll();

  /// Releases resources held by the audio backend.
  Future<void> dispose();
}

/// Production implementation of [AudioBackend] backed by `audioplayers`.
/// Uses a lightweight pool of players for fast, non-overlapping or overlapping SFX.
class AudioplayerBackend implements AudioBackend {
  static const int _poolSize = 4;
  final List<AudioPlayer> _players = [];
  int _nextIndex = 0;
  bool _initialized = false;

  void _init() {
    if (_initialized) return;
    _initialized = true;
    for (var i = 0; i < _poolSize; i++) {
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _players.add(player);
    }
  }

  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {
    _init();
    if (_players.isEmpty) return;

    final player = _players[_nextIndex];
    _nextIndex = (_nextIndex + 1) % _players.length;

    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(assetPath));
    } catch (e, stack) {
      developer.log(
        'AudioplayerBackend failed to play $assetPath: $e',
        name: 'AudioplayerBackend',
        error: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> stopAll() async {
    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}

/// Record of a sound played by [FakeAudioBackend].
class PlayedSoundRecord {
  final String assetPath;
  final double volume;
  final DateTime timestamp;

  PlayedSoundRecord({
    required this.assetPath,
    required this.volume,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Headless in-memory [AudioBackend] for deterministic unit and widget testing.
class FakeAudioBackend implements AudioBackend {
  final List<PlayedSoundRecord> playedSounds = [];
  bool isDisposed = false;

  @override
  Future<void> playAsset(String assetPath, {double volume = 1.0}) async {
    playedSounds.add(PlayedSoundRecord(assetPath: assetPath, volume: volume));
  }

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }

  void clear() => playedSounds.clear();
}
