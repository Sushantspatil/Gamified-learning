import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/chapter_datasource.dart';
import '../../data/datasources/mock/chapter_mock_datasource.dart';
import '../../data/repositories/chapter_repository_impl.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/chapter_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed ChapterDatasource
/// implementation when the backend is ready.
final chapterDatasourceProvider = Provider<ChapterDatasource>((ref) {
  return ChapterMockDatasource();
});

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
