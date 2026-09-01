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
        prompt:
            "Which of the following is the main source of energy for earth's climate system?",
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: 'Solar energy'),
          QuestionOption(id: 'b', text: 'Wind energy'),
          QuestionOption(id: 'c', text: 'Geothermal energy'),
          QuestionOption(id: 'd', text: 'Tidal energy'),
        ],
        correctOptionId: 'b',
        hint: 'Eliminate choices that do not match the topic wording.',
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
        prompt: 'Sort the following account entries into Debit and Credit.',
        points: 10,
        itemsInOrder: const [
          'Purchase',
          'Salary Paid',
          'Discount Allowed',
          'Cash Received',
          'Sales Revenue',
        ],
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
