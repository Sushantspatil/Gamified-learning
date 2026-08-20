import 'package:equatable/equatable.dart';

class Chapter extends Equatable {
  final String id;
  final String learningPathId;
  final String title;
  final String description;
  final int order;
  final int topicCount;

  const Chapter({
    required this.id,
    required this.learningPathId,
    required this.title,
    required this.description,
    required this.order,
    required this.topicCount,
  });

  @override
  List<Object?> get props => [id, learningPathId, title, description, order, topicCount];
}
