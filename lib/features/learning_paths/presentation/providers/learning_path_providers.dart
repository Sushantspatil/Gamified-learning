import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/catalog_learning_path_datasource.dart';
import '../../data/datasources/learning_path_datasource.dart';
import '../../data/datasources/remote/subject_catalog_remote_datasource.dart';
import '../../data/repositories/learning_path_repository_impl.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/entities/subject_catalog.dart';
import '../../domain/repositories/learning_path_repository.dart';

/// Reads `GET /subjects` (tests override this).
final subjectCatalogDatasourceProvider = Provider<SubjectCatalogDatasource>((
  ref,
) {
  return SubjectCatalogRemoteDatasource(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// The database's subjects, loaded once per signed-in player (a topic pack
/// unlocks per player, so a new sign-in loads it again).
final subjectCatalogRepositoryProvider = Provider<SubjectCatalogRepository>((
  ref,
) {
  ref.watch(authControllerProvider.select((auth) => auth.valueOrNull?.id));
  return SubjectCatalogRepository(ref.watch(subjectCatalogDatasourceProvider));
});

final subjectCatalogProvider = FutureProvider<List<SubjectCatalog>>((ref) {
  return ref.watch(subjectCatalogRepositoryProvider).load();
});

/// Learning paths are the subjects in the server's database.
final learningPathDatasourceProvider = Provider<LearningPathDatasource>((ref) {
  // Read at call time so this binding (and the saved selection that depends
  // on it) is not rebuilt on every sign-in.
  return CatalogLearningPathDatasource(
    () => ref.read(subjectCatalogRepositoryProvider),
  );
});

final learningPathRepositoryProvider = Provider<LearningPathRepository>((ref) {
  return LearningPathRepositoryImpl(
    ref.watch(learningPathDatasourceProvider),
    ref.watch(localStorageServiceProvider),
  );
});

/// The catalog of selectable learning paths.
final learningPathsProvider = FutureProvider<List<LearningPath>>((ref) {
  ref.watch(subjectCatalogRepositoryProvider); // reload after a new sign-in
  return ref.watch(learningPathRepositoryProvider).getLearningPaths();
});

/// The user's currently selected path, if any. Drives the onboarding router
/// guard: null means the user still needs to go through onboarding.
class SelectedLearningPathController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref
        .watch(learningPathRepositoryProvider)
        .getSelectedLearningPathId();
  }

  Future<void> select(String id) async {
    state = const AsyncValue<String?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await ref.read(learningPathRepositoryProvider).selectLearningPath(id);
      return id;
    });
  }
}

final selectedLearningPathControllerProvider =
    AsyncNotifierProvider<SelectedLearningPathController, String?>(
      SelectedLearningPathController.new,
    );
