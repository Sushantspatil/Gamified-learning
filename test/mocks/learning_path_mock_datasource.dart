import 'package:skillverse_app/features/learning_paths/domain/entities/learning_path.dart';
import 'package:skillverse_app/features/learning_paths/data/models/learning_path_model.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/learning_path_datasource.dart';

/// MOCK DATA — replace the binding in learning_path_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Do not extend
/// this class with production logic.
class LearningPathMockDatasource implements LearningPathDatasource {
  @override
  Future<List<LearningPathModel>> getLearningPaths() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      LearningPathModel(
        id: 'accounting',
        title: 'Book-Keeping & Accountancy',
        description:
            'Double entry, debit/credit rules, ledger posting, and financial statements.',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 16,
      ),
      LearningPathModel(
        id: 'mental-maths',
        title: 'Mental Maths',
        description:
            'Quick sums: addition, subtraction, multiplication and division.',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 3,
      ),
    ];
  }
}
