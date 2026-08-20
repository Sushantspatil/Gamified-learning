import '../../domain/entities/chapter.dart';

class ChapterModel extends Chapter {
  const ChapterModel({
    required super.id,
    required super.learningPathId,
    required super.title,
    required super.description,
    required super.order,
    required super.topicCount,
  });
}
