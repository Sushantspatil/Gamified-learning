import '../models/chapter_model.dart';
import '../models/topic_model.dart';

/// Implemented today by [ChapterMockDatasource]. Swap for a Firestore-backed
/// implementation (chapters/topics collections) later.
abstract class ChapterDatasource {
  Future<List<ChapterModel>> getChapters(String learningPathId);

  Future<ChapterModel?> getChapterById(String chapterId);

  Future<List<TopicModel>> getTopics(String chapterId);
}
