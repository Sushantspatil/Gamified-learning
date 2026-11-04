import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/config/environment.dart';
import 'core/providers/core_providers.dart';
import 'core/storage/local_storage_service.dart';
import 'features/character3d/presentation/character_3d_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize(Environment.dev);
  final localStorageService = await LocalStorageService.create();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
      ],
      child: const SkillverseApp(),
    ),
  );

  // After the first frame, so it never slows the app's start: warm up the
  // system WebView so the first 3D character appears sooner.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Character3dView.prewarm(),
  );
}
