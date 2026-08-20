import '../../../domain/entities/learning_path.dart';
import '../../models/learning_path_model.dart';
import '../learning_path_datasource.dart';

/// MOCK DATA — replace the binding in learning_path_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Do not extend
/// this class with production logic.
class LearningPathMockDatasource implements LearningPathDatasource {
  @override
  Future<List<LearningPathModel>> getLearningPaths() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      LearningPathModel(
        id: 'web-dev',
        title: 'Web Development',
        description: 'HTML, CSS, JavaScript and modern frameworks.',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 12,
      ),
      LearningPathModel(
        id: 'data-science',
        title: 'Data Science',
        description: 'Statistics, Python and data analysis.',
        difficulty: LearningPathDifficulty.intermediate,
        topicCount: 15,
      ),
      LearningPathModel(
        id: 'ai-ml',
        title: 'AI & Machine Learning',
        description: 'Neural networks, model training and deployment.',
        difficulty: LearningPathDifficulty.advanced,
        topicCount: 18,
      ),
      LearningPathModel(
        id: 'cybersecurity',
        title: 'Cybersecurity',
        description: 'Network security, ethical hacking and cryptography.',
        difficulty: LearningPathDifficulty.intermediate,
        topicCount: 10,
      ),
    ];
  }
}
