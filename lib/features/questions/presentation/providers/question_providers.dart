import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock/question_mock_datasource.dart';
import '../../data/datasources/question_datasource.dart';
import '../../data/repositories/question_repository_impl.dart';
import '../../domain/entities/question.dart';
import '../../domain/repositories/question_repository.dart';

/// MOCK BINDING — swap for a Firestore-backed QuestionDatasource
/// implementation when the backend is ready.
final questionDatasourceProvider = Provider<QuestionDatasource>((ref) {
  return QuestionMockDatasource();
});

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepositoryImpl(ref.watch(questionDatasourceProvider));
});

final questionsForTopicProvider = FutureProvider.family<List<Question>, String>(
  (ref, topicId) {
    return ref.watch(questionRepositoryProvider).getQuestionsForTopic(topicId);
  },
);

class QuestionsForTopicAndTypeRequest {
  final String topicId;
  final QuestionType questionType;

  const QuestionsForTopicAndTypeRequest({
    required this.topicId,
    required this.questionType,
  });

  @override
  bool operator ==(Object other) {
    return other is QuestionsForTopicAndTypeRequest &&
        other.topicId == topicId &&
        other.questionType == questionType;
  }

  @override
  int get hashCode => Object.hash(topicId, questionType);
}

final questionsForTopicAndTypeProvider =
    FutureProvider.family<List<Question>, QuestionsForTopicAndTypeRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(questionRepositoryProvider)
          .getQuestionsForTopicAndType(request.topicId, request.questionType);
    });
