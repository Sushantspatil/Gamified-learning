import '../models/chapter_model.dart';
import '../models/topic_model.dart';

/// Implemented by `CatalogChapterDatasource` (the server's `GET /subjects`).
/// Tests use a mock from `test/mocks/`.
abstract class ChapterDatasource {
  Future<List<ChapterModel>> getChapters(String learningPathId);

  Future<ChapterModel?> getChapterById(String chapterId);

  Future<List<TopicModel>> getTopics(String chapterId);
}
