import 'package:equatable/equatable.dart';

enum LearningPathDifficulty { beginner, intermediate, advanced }

class LearningPath extends Equatable {
  final String id;
  final String title;
  final String description;
  final LearningPathDifficulty difficulty;
  final int topicCount;

  const LearningPath({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.topicCount,
  });

  @override
  List<Object?> get props => [id, title, description, difficulty, topicCount];
}
