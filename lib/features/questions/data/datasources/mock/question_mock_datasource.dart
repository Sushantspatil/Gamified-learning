import '../../../domain/entities/question.dart';
import '../question_datasource.dart';

/// MOCK DATA - replace the binding in question_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Every topic gets
/// a complete playable demo set for each supported question type.
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
      ..._mcqQuestions(topicId),
      ..._matchQuestions(topicId),
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
      ..._suddenDeathQuestions(topicId),
    ];
  }

  List<McqQuestion> _mcqQuestions(String topicId) {
    return [
      McqQuestion(
        id: '$topicId-mcq-1',
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
        correctOptionId: 'a',
        hint: 'Think about the source that drives weather and climate.',
      ),
      McqQuestion(
        id: '$topicId-mcq-2',
        topicId: topicId,
        prompt: 'In HTML, which tag is used for the largest heading?',
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: '<heading>'),
          QuestionOption(id: 'b', text: '<h1>'),
          QuestionOption(id: 'c', text: '<head>'),
          QuestionOption(id: 'd', text: '<title>'),
        ],
        correctOptionId: 'b',
        hint: 'Heading tags are numbered from largest to smallest.',
      ),
      McqQuestion(
        id: '$topicId-mcq-3',
        topicId: topicId,
        prompt: 'Which CSS property changes the text color of an element?',
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: 'font-style'),
          QuestionOption(id: 'b', text: 'background-color'),
          QuestionOption(id: 'c', text: 'color'),
          QuestionOption(id: 'd', text: 'text-size'),
        ],
        correctOptionId: 'c',
        hint: 'It is the direct property name for foreground text color.',
      ),
      McqQuestion(
        id: '$topicId-mcq-4',
        topicId: topicId,
        prompt: 'What does the HTML anchor tag primarily create?',
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: 'A table row'),
          QuestionOption(id: 'b', text: 'A hyperlink'),
          QuestionOption(id: 'c', text: 'A numbered list'),
          QuestionOption(id: 'd', text: 'A page heading'),
        ],
        correctOptionId: 'b',
        hint: 'Anchors usually use an href attribute.',
      ),
      McqQuestion(
        id: '$topicId-mcq-5',
        topicId: topicId,
        prompt: 'Which JavaScript keyword declares a block-scoped variable?',
        points: 10,
        options: const [
          QuestionOption(id: 'a', text: 'var'),
          QuestionOption(id: 'b', text: 'let'),
          QuestionOption(id: 'c', text: 'def'),
          QuestionOption(id: 'd', text: 'dim'),
        ],
        correctOptionId: 'b',
        hint: 'Modern JavaScript uses this keyword alongside const.',
      ),
    ];
  }

  List<MatchTheFollowingQuestion> _matchQuestions(String topicId) {
    return [
      MatchTheFollowingQuestion(
        id: '$topicId-match-1',
        topicId: topicId,
        prompt: 'Match each web term with its role.',
        points: 15,
        pairs: const [
          MatchPair(id: 'html', left: 'HTML', right: 'Page structure'),
          MatchPair(id: 'css', left: 'CSS', right: 'Visual styling'),
          MatchPair(id: 'js', left: 'JavaScript', right: 'Interactivity'),
        ],
      ),
      MatchTheFollowingQuestion(
        id: '$topicId-match-2',
        topicId: topicId,
        prompt: 'Match each HTML element with its common use.',
        points: 15,
        pairs: const [
          MatchPair(id: 'p', left: '<p>', right: 'Paragraph text'),
          MatchPair(id: 'img', left: '<img>', right: 'Image content'),
          MatchPair(id: 'ul', left: '<ul>', right: 'Unordered list'),
        ],
      ),
      MatchTheFollowingQuestion(
        id: '$topicId-match-3',
        topicId: topicId,
        prompt: 'Match each CSS selector with what it targets.',
        points: 15,
        pairs: const [
          MatchPair(id: 'class', left: '.card', right: 'Class name'),
          MatchPair(id: 'id', left: '#hero', right: 'Unique id'),
          MatchPair(id: 'element', left: 'button', right: 'Element type'),
        ],
      ),
      MatchTheFollowingQuestion(
        id: '$topicId-match-4',
        topicId: topicId,
        prompt: 'Match each browser concept with its meaning.',
        points: 15,
        pairs: const [
          MatchPair(id: 'dom', left: 'DOM', right: 'Document object model'),
          MatchPair(id: 'url', left: 'URL', right: 'Web address'),
          MatchPair(id: 'http', left: 'HTTP', right: 'Transfer protocol'),
        ],
      ),
      MatchTheFollowingQuestion(
        id: '$topicId-match-5',
        topicId: topicId,
        prompt: 'Match each accessibility term with its purpose.',
        points: 15,
        pairs: const [
          MatchPair(id: 'alt', left: 'Alt text', right: 'Describes images'),
          MatchPair(id: 'label', left: 'Label', right: 'Names form fields'),
          MatchPair(id: 'focus', left: 'Focus', right: 'Keyboard location'),
        ],
      ),
    ];
  }

  List<SuddenDeathQuestion> _suddenDeathQuestions(String topicId) {
    return [
      SuddenDeathQuestion(
        id: '$topicId-sudden-death-1',
        topicId: topicId,
        prompt: 'Which option is a valid HTML paragraph tag?',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: '<p>'),
          QuestionOption(id: 'y', text: '<paragraph>'),
        ],
        correctOptionId: 'x',
      ),
      SuddenDeathQuestion(
        id: '$topicId-sudden-death-2',
        topicId: topicId,
        prompt: 'Which CSS property controls background color?',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: 'background-color'),
          QuestionOption(id: 'y', text: 'font-weight'),
        ],
        correctOptionId: 'x',
      ),
      SuddenDeathQuestion(
        id: '$topicId-sudden-death-3',
        topicId: topicId,
        prompt: 'Which attribute gives an image its source file?',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: 'src'),
          QuestionOption(id: 'y', text: 'href'),
        ],
        correctOptionId: 'x',
      ),
      SuddenDeathQuestion(
        id: '$topicId-sudden-death-4',
        topicId: topicId,
        prompt: 'Which JavaScript value represents true or false?',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: 'Boolean'),
          QuestionOption(id: 'y', text: 'String'),
        ],
        correctOptionId: 'x',
      ),
      SuddenDeathQuestion(
        id: '$topicId-sudden-death-5',
        topicId: topicId,
        prompt: 'Which tag creates a clickable link?',
        points: 20,
        options: const [
          QuestionOption(id: 'x', text: '<a>'),
          QuestionOption(id: 'y', text: '<link-only>'),
        ],
        correctOptionId: 'x',
      ),
    ];
  }
}
