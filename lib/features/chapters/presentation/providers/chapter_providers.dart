import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/chapter_datasource.dart';
import '../../data/models/chapter_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/chapter_repository_impl.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/chapter_repository.dart';

/// Backend-supported chapter/topic binding.
final chapterDatasourceProvider = Provider<ChapterDatasource>((ref) {
  return const BackendChapterDatasource();
});

class BackendChapterDatasource implements ChapterDatasource {
  const BackendChapterDatasource();

  static const _chapter = ChapterModel(
    id: 'accounting-basics',
    learningPathId: 'accounting',
    title: 'Book-Keeping & Accountancy',
    description: 'Practice questions from the deployed backend.',
    order: 1,
    topicCount: 1,
  );

  static const _topic = TopicModel(
    id: 'accounting',
    chapterId: 'accounting-basics',
    title: 'Backend quiz',
    order: 1,
    isCompleted: false,
  );

  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    return learningPathId == 'accounting' ? const [_chapter] : const [];
  }

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async {
    return chapterId == _chapter.id ? _chapter : null;
  }

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    return chapterId == _chapter.id ? const [_topic] : const [];
  }
}

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepositoryImpl(ref.watch(chapterDatasourceProvider));
});

final chaptersProvider = FutureProvider.family<List<Chapter>, String>((
  ref,
  learningPathId,
) {
  return ref.watch(chapterRepositoryProvider).getChapters(learningPathId);
});

final chapterByIdProvider = FutureProvider.family<Chapter?, String>((
  ref,
  chapterId,
) {
  return ref.watch(chapterRepositoryProvider).getChapterById(chapterId);
});

final topicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  chapterId,
) {
  return ref.watch(chapterRepositoryProvider).getTopics(chapterId);
});
