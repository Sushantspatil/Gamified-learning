import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage_service.dart';

/// Overridden in main() with the instance created via
/// LocalStorageService.create() before runApp is called.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden in main()');
});
