import '../entities/chapter.dart';
import '../entities/topic.dart';

abstract class ChapterRepository {
  Future<List<Chapter>> getChapters(String learningPathId);

  Future<Chapter?> getChapterById(String chapterId);

  Future<List<Topic>> getTopics(String chapterId);
}
