import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/storage/storage_keys.dart';

enum AppThemePreference {
  light('light'),
  dark('dark');

  final String storageValue;

  const AppThemePreference(this.storageValue);

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  String get label {
    return switch (this) {
      AppThemePreference.light => 'Light',
      AppThemePreference.dark => 'Dark',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemePreference.light => Icons.light_mode_outlined,
      AppThemePreference.dark => Icons.dark_mode_outlined,
    };
  }

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.storageValue == value,
      orElse: () => AppThemePreference.dark,
    );
  }
}

class ThemeModeController extends Notifier<AppThemePreference> {
  @override
  AppThemePreference build() {
    final storage = ref.watch(localStorageServiceProvider);
    return AppThemePreference.fromStorage(storage.getString(StorageKeys.themePreference));
  }

  Future<void> setTheme(AppThemePreference preference) async {
    if (state == preference) return;

    state = preference;
    await ref.read(localStorageServiceProvider).setString(
          StorageKeys.themePreference,
          preference.storageValue,
        );
  }

  Future<void> toggleTheme() async {
    final next = state == AppThemePreference.dark
        ? AppThemePreference.light
        : AppThemePreference.dark;
    await setTheme(next);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, AppThemePreference>(ThemeModeController.new);
