import '../entities/learning_path.dart';

abstract class LearningPathRepository {
  Future<List<LearningPath>> getLearningPaths();

  Future<String?> getSelectedLearningPathId();

  Future<void> selectLearningPath(String id);
}
