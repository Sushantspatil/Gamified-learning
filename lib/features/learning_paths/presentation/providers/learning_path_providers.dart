import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/learning_path_datasource.dart';
import '../../data/models/learning_path_model.dart';
import '../../data/repositories/learning_path_repository_impl.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_path_repository.dart';

/// Backend-supported learning path binding.
final learningPathDatasourceProvider = Provider<LearningPathDatasource>((ref) {
  return const BackendLearningPathDatasource();
});

class BackendLearningPathDatasource implements LearningPathDatasource {
  const BackendLearningPathDatasource();

  @override
  Future<List<LearningPathModel>> getLearningPaths() async {
    return const [
      LearningPathModel(
        id: 'accounting',
        title: 'Book-Keeping & Accountancy',
        description: 'Questions are loaded from the deployed backend.',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 1,
      ),
    ];
  }
}

final learningPathRepositoryProvider = Provider<LearningPathRepository>((ref) {
  return LearningPathRepositoryImpl(
    ref.watch(learningPathDatasourceProvider),
    ref.watch(localStorageServiceProvider),
  );
});

/// The catalog of selectable learning paths.
final learningPathsProvider = FutureProvider<List<LearningPath>>((ref) {
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
