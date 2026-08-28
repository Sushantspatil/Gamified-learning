import '../../domain/entities/chapter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../datasources/chapter_datasource.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  final ChapterDatasource _datasource;

  ChapterRepositoryImpl(this._datasource);

  @override
  Future<List<Chapter>> getChapters(String learningPathId) =>
      _datasource.getChapters(learningPathId);

  @override
  Future<Chapter?> getChapterById(String chapterId) =>
      _datasource.getChapterById(chapterId);

  @override
  Future<List<Topic>> getTopics(String chapterId) =>
      _datasource.getTopics(chapterId);
}
