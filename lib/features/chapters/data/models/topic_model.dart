import '../../domain/entities/topic.dart';

class TopicModel extends Topic {
  const TopicModel({
    required super.id,
    required super.chapterId,
    required super.title,
    required super.order,
    required super.isCompleted,
  });
}
