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

  static const _accountingChapter = ChapterModel(
    id: 'accounting-basics',
    learningPathId: 'accounting',
    title: 'Book-Keeping & Accountancy',
    description: 'Practice questions from the deployed backend.',
    order: 1,
    topicCount: 1,
  );

  static const _accountingTopic = TopicModel(
    id: 'accounting',
    chapterId: 'accounting-basics',
    title: 'Backend quiz',
    order: 1,
    isCompleted: false,
  );

  static const _mathsChapter = ChapterModel(
    id: 'maths-basics',
    learningPathId: 'maths',
    title: 'Mathematics',
    description: 'Practice questions from the deployed backend.',
    order: 1,
    topicCount: 1,
  );

  static const _mathsTopic = TopicModel(
    id: 'maths',
    chapterId: 'maths-basics',
    title: 'Mathematics Quiz',
    order: 1,
    isCompleted: false,
  );

  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    if (learningPathId == 'accounting') return const [_accountingChapter];
    if (learningPathId == 'maths' || learningPathId == 'math') return const [_mathsChapter];
    return const [];
  }

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async {
    if (chapterId == _accountingChapter.id) return _accountingChapter;
    if (chapterId == _mathsChapter.id) return _mathsChapter;
    return null;
  }

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    if (chapterId == _accountingChapter.id) return const [_accountingTopic];
    if (chapterId == _mathsChapter.id) return const [_mathsTopic];
    return const [];
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
