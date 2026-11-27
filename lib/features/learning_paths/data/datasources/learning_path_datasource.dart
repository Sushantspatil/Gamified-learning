import '../models/learning_path_model.dart';

/// Implemented by `CatalogLearningPathDatasource` (the server's
/// `GET /subjects`). Tests use a mock from `test/mocks/`.
abstract class LearningPathDatasource {
  Future<List<LearningPathModel>> getLearningPaths();
}
