import '../../../domain/entities/question.dart';
import '../question_datasource.dart';

/// MOCK DATA — replace the binding in question_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Every topic
/// gets one question of each of the four required types.
class QuestionMockDatasource implements QuestionDatasource {
  @override
  Future<List<Question>> getQuestionsForTopic(String topicId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    return _questionsForTopic(topicId);
  }

  @override
  Future<List<Question>> getQuestionsForTopicAndType(
    String topicId,
    QuestionType questionType,
  ) async {
    final questions = await getQuestionsForTopic(topicId);
    return questions
        .where((question) => question.type == questionType)
        .toList();
  }

  List<Question> _questionsForTopic(String topicId) {
    return [
      McqQuestion(
        id: '$topicId-mcq',
        topicId: topicId,
        prompt: 'Which of the following best applies to this topic?',
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: 'Option A'),
          QuestionOption(id: 'b', text: 'Option B'),
          QuestionOption(id: 'c', text: 'Option C'),
        ],
        correctOptionId: 'b',
      ),
      MatchTheFollowingQuestion(
        id: '$topicId-match',
        topicId: topicId,
        prompt: 'Match each term with its correct definition.',
        points: 15,
        pairs: const [
          MatchPair(
            id: 'p1',
            left: 'Term 1',
            right: 'Definition 1',
            hint: 'Look for the definition that directly explains Term 1.',
          ),
          MatchPair(
            id: 'p2',
            left: 'Term 2',
            right: 'Definition 2',
            hint: 'This concept is paired with the second definition.',
          ),
          MatchPair(
            id: 'p3',
            left: 'Term 3',
            right: 'Definition 3',
            hint: 'Think about the definition that completes the third pair.',
          ),
        ],
      ),
      SortItRightQuestion(
        id: '$topicId-sort',
        topicId: topicId,
        prompt: 'Arrange these steps in the correct order.',
        points: 15,
        itemsInOrder: const ['Step 1', 'Step 2', 'Step 3', 'Step 4'],
      ),
      SuddenDeathQuestion(
        id: '$topicId-sudden-death',
        topicId: topicId,
        prompt: 'Sudden Death: one wrong answer ends the quiz!',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: 'Choice X'),
          QuestionOption(id: 'y', text: 'Choice Y'),
        ],
        correctOptionId: 'x',
      ),
    ];
  }
}
