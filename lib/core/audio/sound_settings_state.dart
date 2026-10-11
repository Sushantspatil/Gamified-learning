import 'package:equatable/equatable.dart';

/// State representation of the user's audio preferences.
class SoundSettingsState extends Equatable {
  /// Whether sound effects (SFX) should be played. Defaults to true.
  final bool sfxEnabled;

  /// Whether background music should be played in future phases. Defaults to true.
  final bool musicEnabled;

  const SoundSettingsState({
    this.sfxEnabled = true,
    this.musicEnabled = true,
  });

  SoundSettingsState copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
  }) {
    return SoundSettingsState(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
    );
  }

  @override
  List<Object?> get props => [sfxEnabled, musicEnabled];
}
