import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../questions/data/datasources/mock/question_mock_datasource.dart';
import '../../../questions/domain/entities/question.dart';

/// Dedicated development-only Sudden Death questions.
///
/// Release builds always receive an empty list, so production availability
/// continues to depend exclusively on backend-provided questions.
final suddenDeathPreviewQuestionsProvider =
    AutoDisposeFutureProvider.family<List<SuddenDeathQuestion>, String>((
      ref,
      topicId,
    ) async {
      if (!AppConfig.developmentPreviewsEnabled) return const [];

      final questions = await QuestionMockDatasource()
          .getQuestionsForTopicAndType(topicId, QuestionType.suddenDeath);

      return questions
          .whereType<SuddenDeathQuestion>()
          .where((question) => question.options.length >= 2)
          .toList(growable: false);
    });
