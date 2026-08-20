import '../models/learning_path_model.dart';

/// Implemented today by [LearningPathMockDatasource]. Swap the provider
/// binding to a Firestore-backed implementation (learningPaths collection)
/// later without changing the repository or presentation layer.
abstract class LearningPathDatasource {
  Future<List<LearningPathModel>> getLearningPaths();
}
