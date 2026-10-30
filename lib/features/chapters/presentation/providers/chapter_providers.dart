import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/chapter_datasource.dart';
import '../../data/datasources/mock/chapter_mock_datasource.dart';
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

  static const _chapters = [
    ChapterModel(
      id: 'accounting-basics',
      learningPathId: 'accounting',
      title: 'Book-Keeping & Accountancy',
      description: 'Practice questions from the deployed backend.',
      order: 1,
      topicCount: 1,
    ),
    ChapterModel(
      id: 'maths-basics',
      learningPathId: 'maths',
      title: 'Mathematics',
      description: 'Practice questions from the deployed backend.',
      order: 2,
      topicCount: 1,
    ),
    ChapterModel(
      id: 'mental-maths-levels',
      learningPathId: 'mental-maths',
      title: 'Mental Maths',
      description: 'Pick a level: Easy, Medium or Hard.',
      order: 3,
      topicCount: 3,
    ),
  ];

  static const _topics = [
    TopicModel(
      id: 'accounting',
      chapterId: 'accounting-basics',
      title: 'Backend quiz',
      order: 1,
      isCompleted: false,
    ),
    TopicModel(
      id: 'maths',
      chapterId: 'maths-basics',
      title: 'Mathematics Quiz',
      order: 1,
      isCompleted: false,
    ),
    TopicModel(
      id: 'mental-maths-easy',
      chapterId: 'mental-maths-levels',
      title: 'Easy: Addition & Subtraction',
      order: 1,
      isCompleted: false,
    ),
    TopicModel(
      id: 'mental-maths-medium',
      chapterId: 'mental-maths-levels',
      title: 'Medium: Multiplication',
      order: 2,
      isCompleted: false,
    ),
    TopicModel(
      id: 'mental-maths-hard',
      chapterId: 'mental-maths-levels',
      title: 'Hard: Division & 2-digit × 1-digit',
      order: 3,
      isCompleted: false,
    ),
  ];

  static final _mockDatasource = ChapterMockDatasource();

  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    final normalized = learningPathId.trim().toLowerCase();
    final matched = _chapters.where((c) {
      if (c.learningPathId == normalized) return true;
      if (c.learningPathId == 'maths' &&
          (normalized == 'math' ||
              normalized == 'maths1' ||
              normalized == 'mathematics')) {
        return true;
      }
      if (c.learningPathId == 'accounting' && normalized == 'accounts') {
        return true;
      }
      return false;
    }).toList();

    if (matched.isNotEmpty) return matched;
    return _mockDatasource.getChapters(learningPathId);
  }

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async {
    for (final c in _chapters) {
      if (c.id == chapterId) return c;
    }
    return _mockDatasource.getChapterById(chapterId);
  }

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    final matched = _topics.where((t) => t.chapterId == chapterId).toList();
    if (matched.isNotEmpty) return matched;
    return _mockDatasource.getTopics(chapterId);
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
