import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/reward_calculator.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
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
class QuizSessionRequest {
  final String topicId;
  final QuestionType quizType;
  final String? subjectId;
  final String? chapterId;

  const QuizSessionRequest({
    required this.topicId,
    required this.quizType,
    this.subjectId,
    this.chapterId,
  });

  @override
  bool operator ==(Object other) {
    return other is QuizSessionRequest &&
        other.topicId == topicId &&
        other.quizType == quizType &&
        other.subjectId == subjectId &&
        other.chapterId == chapterId;
  }

  @override
  int get hashCode => Object.hash(topicId, quizType, subjectId, chapterId);
}

class QuizController
    extends FamilyAsyncNotifier<QuizSessionViewState, QuizSessionRequest> {
  late final String _sessionId;
  late final QuizSessionRequest _request;
  late final DateTime _startedAt;

  @override
  Future<QuizSessionViewState> build(QuizSessionRequest request) async {
    _request = request;
    _startedAt = DateTime.now();
    _sessionId =
        'session-${request.topicId}-${request.quizType.routeValue}-${_startedAt.microsecondsSinceEpoch}';
    final questions = await ref.watch(
      questionsForTopicAndTypeProvider(
        QuestionsForTopicAndTypeRequest(
          topicId: request.topicId,
          questionType: request.quizType,
        ),
      ).future,
    );

    return QuizSessionViewState(
      topicId: request.topicId,
      quizType: request.quizType,
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

    final evaluation = await ref
        .read(quizRepositoryProvider)
        .evaluateAnswer(question, answer);
    final record = QuestionAnswerRecord(
      question: question,
      answer: answer,
      evaluation: evaluation,
    );
    final updatedRecords = [...current.records, record];

    final isSuddenDeathFailure =
        question is SuddenDeathQuestion && !evaluation.isCorrect;
    final nextIndex = current.currentIndex + 1;
    final reachedEnd = nextIndex >= current.questions.length;

    if (isSuddenDeathFailure || reachedEnd) {
      state = AsyncValue.data(
        current.copyWith(
          records: updatedRecords,
          currentIndex: nextIndex,
          isSubmittingResult: true,
        ),
      );

      final session = QuizSession(
        id: _sessionId,
        userId: ref.read(authControllerProvider).valueOrNull?.id,
        subjectId: _request.subjectId,
        chapterId: _request.chapterId,
        topicId: _request.topicId,
        quizType: _request.quizType,
        questions: current.questions,
        answeredRecords: updatedRecords,
        endedEarly: isSuddenDeathFailure,
        startedAt: _startedAt,
        completedAt: DateTime.now(),
      );
      final result = await ref
          .read(quizRepositoryProvider)
          .submitSession(session);

      final previousLevel = ref
          .read(profileControllerProvider)
          .valueOrNull
          ?.level;
      final reward = RewardCalculator.forEarnedPoints(
        result.score.earnedPoints,
      );
      final updatedProfile = await ref
          .read(profileControllerProvider.notifier)
          .addXp(reward.xp);
      final leveledUp =
          previousLevel != null &&
          updatedProfile != null &&
          updatedProfile.level > previousLevel;

      await ref
          .read(walletControllerProvider.notifier)
          .credit(
            currency: CurrencyType.coins,
            amount: reward.coins,
            reason: 'Quiz reward',
          );
      await ref
          .read(dailyMissionsControllerProvider.notifier)
          .recordQuizCompletion();

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
      state = AsyncValue.data(
        current.copyWith(records: updatedRecords, currentIndex: nextIndex),
      );
    }
  }
}

final quizControllerProvider =
    AsyncNotifierProvider.family<
      QuizController,
      QuizSessionViewState,
      QuizSessionRequest
    >(QuizController.new);
