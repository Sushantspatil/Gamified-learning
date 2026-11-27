import '../../../../core/network/backend_topic_mapper.dart';
import '../../../learning_paths/data/datasources/catalog_learning_path_datasource.dart';
import '../../../learning_paths/data/datasources/remote/subject_catalog_remote_datasource.dart';
import '../../../learning_paths/domain/entities/subject_catalog.dart';
import '../models/chapter_model.dart';
import '../models/topic_model.dart';
import 'chapter_datasource.dart';

/// Chapters and topics from the server's database.
///
/// A subject's chapters are "All chapters (mixed)" followed by its real
/// chapters. Each chapter has one topic (the Play screen picks it on its own)
/// whose id carries the subject and chapter, so every game mode plays exactly
/// that chapter (`backendChapterNoForTopic`).
class CatalogChapterDatasource implements ChapterDatasource {
  final SubjectCatalogRepository Function() _catalog;

  const CatalogChapterDatasource(this._catalog);

  static const allChaptersTitle = 'All chapters (mixed)';

  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    final subject = await _catalog().subjectFor(learningPathId);
    if (subject == null) return const [];
    final pathId = learningPathIdForSubjectCode(subject.code);
    final real = subject.chapters.where((c) => c.hasContent).toList();
    return [
      if (real.length > 1)
        ChapterModel(
          id: catalogAllChaptersId(subject.code),
          learningPathId: pathId,
          title: allChaptersTitle,
          description: describeModes(subject.countFor),
          order: 0,
          topicCount: 1,
        ),
      for (final c in real) _chapter(subject, c, pathId),
    ];
  }

  ChapterModel _chapter(SubjectCatalog s, CatalogChapter c, String pathId) =>
      ChapterModel(
        id: catalogChapterId(s.code, c.chapterNo),
        learningPathId: pathId,
        title: c.title,
        description: describeModes(c.countFor),
        order: c.chapterNo,
        topicCount: 1,
      );

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async {
    final ref = parseCatalogChapterId(chapterId);
    if (ref == null) return null;
    final subject = await _catalog().subjectFor(ref.subjectCode);
    if (subject == null) return null;
    final chapters = await getChapters(subject.code);
    for (final c in chapters) {
      if (c.id == chapterId) return c;
    }
    return null;
  }

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    final chapter = await getChapterById(chapterId);
    final ref = parseCatalogChapterId(chapterId);
    if (chapter == null || ref == null) return const [];
    final no = ref.chapterNo;
    return [
      TopicModel(
        id: no == null
            ? catalogSubjectTopicId(ref.subjectCode)
            : catalogChapterTopicId(ref.subjectCode, no),
        chapterId: chapterId,
        title: chapter.title,
        order: 1,
        isCompleted: false,
      ),
    ];
  }
}
