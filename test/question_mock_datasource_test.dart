import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/features/questions/data/datasources/mock/question_mock_datasource.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';

void main() {
  test(
    'mock demo topic has complete sessions for every mockable game mode',
    () async {
      final datasource = QuestionMockDatasource();
      final questions = await datasource.getQuestionsForTopic('tags-elements');

      final mcqQuestions = questions.whereType<McqQuestion>().toList();
      final matchQuestions = questions
          .whereType<MatchTheFollowingQuestion>()
          .toList();
      final sortQuestions = questions.whereType<SortItRightQuestion>().toList();

      expect(mcqQuestions, hasLength(greaterThanOrEqualTo(5)));
      expect(matchQuestions, hasLength(greaterThanOrEqualTo(5)));
      expect(
        sortQuestions.single.itemsInOrder,
        hasLength(greaterThanOrEqualTo(5)),
      );
      expect(
        mcqQuestions.every((question) => question.options.length == 4),
        isTrue,
      );
      expect(
        matchQuestions.every((question) => question.pairs.length >= 3),
        isTrue,
      );
    },
  );

  // Sudden Death is served exclusively by the live backend over the WebSocket
  // API. The mock datasource must never supply its questions.
  test('mock datasource never serves Sudden Death questions', () async {
    final datasource = QuestionMockDatasource();

    final all = await datasource.getQuestionsForTopic('tags-elements');
    expect(all.whereType<SuddenDeathQuestion>(), isEmpty);

    final byType = await datasource.getQuestionsForTopicAndType(
      'tags-elements',
      QuestionType.suddenDeath,
    );
    expect(byType, isEmpty);
  });
}
