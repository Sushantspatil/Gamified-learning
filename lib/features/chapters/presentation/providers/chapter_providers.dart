import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../data/datasources/catalog_chapter_datasource.dart';
import '../../data/datasources/chapter_datasource.dart';
import '../../data/repositories/chapter_repository_impl.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/chapter_repository.dart';

/// Chapters and topics from the server's database (`GET /subjects`).
final chapterDatasourceProvider = Provider<ChapterDatasource>((ref) {
  return CatalogChapterDatasource(
    () => ref.read(subjectCatalogRepositoryProvider),
  );
});

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepositoryImpl(ref.watch(chapterDatasourceProvider));
});

final chaptersProvider = FutureProvider.family<List<Chapter>, String>((
  ref,
  learningPathId,
) {
  ref.watch(subjectCatalogRepositoryProvider); // reload after a new sign-in
  return ref.watch(chapterRepositoryProvider).getChapters(learningPathId);
});

final chapterByIdProvider = FutureProvider.family<Chapter?, String>((
  ref,
  chapterId,
) {
  ref.watch(subjectCatalogRepositoryProvider); // reload after a new sign-in
  return ref.watch(chapterRepositoryProvider).getChapterById(chapterId);
});

final topicsProvider = FutureProvider.family<List<Topic>, String>((
  ref,
  chapterId,
) {
  ref.watch(subjectCatalogRepositoryProvider); // reload after a new sign-in
  return ref.watch(chapterRepositoryProvider).getTopics(chapterId);
});
