import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/reward_calculator.dart';
import '../../../daily_missions/presentation/providers/daily_mission_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../../../questions/presentation/providers/question_providers.dart';
import '../../../wallet/domain/entities/currency_type.dart';
import '../../../wallet/presentation/providers/wallet_providers.dart';
import '../../data/datasources/mock/quiz_mock_datasource.dart';
import '../../data/datasources/quiz_datasource.dart';
import '../../data/repositories/quiz_repository_impl.dart';
import '../../domain/entities/question_answer_record.dart';
import '../../domain/entities/quiz_session.dart';
import '../../domain/repositories/quiz_repository.dart';
import 'quiz_session_view_state.dart';

/// MOCK BINDING — swap for a datasource that calls a Cloud Function once
/// scores must be server-authoritative.
final quizDatasourceProvider = Provider<QuizDatasource>((ref) {
  return QuizMockDatasource();
});

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepositoryImpl(ref.watch(quizDatasourceProvider));
});

/// Drives one quiz attempt for a topic: loads questions, records each
/// answer's evaluation, enforces the Sudden Death early-exit rule, and
/// submits the finished session for a final result. All scoring math is
/// delegated to QuizRepository — this class only orchestrates progression.
class QuizController extends FamilyAsyncNotifier<QuizSessionViewState, String> {
  late final String _sessionId;
  late final String _topicId;

  @override
  Future<QuizSessionViewState> build(String topicId) async {
    _topicId = topicId;
    _sessionId = 'session-$topicId-${DateTime.now().microsecondsSinceEpoch}';
    final questions = await ref.watch(questionsForTopicProvider(topicId).future);

    return QuizSessionViewState(
      questions: questions,
      currentIndex: 0,
      records: const [],
      isSubmittingResult: false,
      result: null,
    );
  }

  Future<void> submitAnswer(Answer answer) async {
    final current = state.valueOrNull;
    if (current == null || current.result != null) return;

    final question = current.currentQuestion;
    if (question == null) return;

    final evaluation = await ref.read(quizRepositoryProvider).evaluateAnswer(question, answer);
    final record = QuestionAnswerRecord(question: question, answer: answer, evaluation: evaluation);
    final updatedRecords = [...current.records, record];

    final isSuddenDeathFailure = question is SuddenDeathQuestion && !evaluation.isCorrect;
    final nextIndex = current.currentIndex + 1;
    final reachedEnd = nextIndex >= current.questions.length;

    if (isSuddenDeathFailure || reachedEnd) {
      state = AsyncValue.data(
        current.copyWith(records: updatedRecords, currentIndex: nextIndex, isSubmittingResult: true),
      );

      final session = QuizSession(
        id: _sessionId,
        topicId: _topicId,
        questions: current.questions,
        answeredRecords: updatedRecords,
        endedEarly: isSuddenDeathFailure,
      );
      final result = await ref.read(quizRepositoryProvider).submitSession(session);

      final previousLevel = ref.read(profileControllerProvider).valueOrNull?.level;
      final reward = RewardCalculator.forEarnedPoints(result.score.earnedPoints);
      final updatedProfile =
          await ref.read(profileControllerProvider.notifier).addXp(reward.xp);
      final leveledUp =
          previousLevel != null && updatedProfile != null && updatedProfile.level > previousLevel;

      await ref.read(walletControllerProvider.notifier).credit(
            currency: CurrencyType.coins,
            amount: reward.coins,
            reason: 'Quiz reward',
          );
      await ref.read(dailyMissionsControllerProvider.notifier).recordQuizCompletion();

      state = AsyncValue.data(
        current.copyWith(
          records: updatedRecords,
          currentIndex: nextIndex,
          isSubmittingResult: false,
          result: result,
          rewardXp: reward.xp,
          rewardCoins: reward.coins,
          leveledUp: leveledUp,
        ),
      );
    } else {
      state = AsyncValue.data(current.copyWith(records: updatedRecords, currentIndex: nextIndex));
    }
  }
}

final quizControllerProvider =
    AsyncNotifierProvider.family<QuizController, QuizSessionViewState, String>(QuizController.new);
