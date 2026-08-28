import '../../domain/entities/learning_path.dart';

class LearningPathModel extends LearningPath {
  const LearningPathModel({
    required super.id,
    required super.title,
    required super.description,
    required super.difficulty,
    required super.topicCount,
  });

  factory LearningPathModel.fromJson(Map<String, dynamic> json) =>
      LearningPathModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        difficulty: LearningPathDifficulty.values.byName(
          json['difficulty'] as String,
        ),
        topicCount: json['topicCount'] as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'difficulty': difficulty.name,
    'topicCount': topicCount,
  };
}
