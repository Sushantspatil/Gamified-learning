import '../../../questions/domain/entities/question.dart';
import '../../domain/entities/question_answer_record.dart';
import '../../domain/entities/quiz_result.dart';

class QuizSessionViewState {
  final String topicId;
  final QuestionType quizType;
  final List<Question> questions;
  final int currentIndex;
  final List<QuestionAnswerRecord> records;
  final bool isSubmittingResult;
  final QuizResult? result;
  final int? rewardXp;
  final int? rewardCoins;
  final bool leveledUp;

  const QuizSessionViewState({
    required this.topicId,
    required this.quizType,
    required this.questions,
    required this.currentIndex,
    required this.records,
    required this.isSubmittingResult,
    required this.result,
    this.rewardXp,
    this.rewardCoins,
    this.leveledUp = false,
  });

  Question? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  QuizSessionViewState copyWith({
    int? currentIndex,
    List<QuestionAnswerRecord>? records,
    bool? isSubmittingResult,
    QuizResult? result,
    int? rewardXp,
    int? rewardCoins,
    bool? leveledUp,
  }) {
    return QuizSessionViewState(
      topicId: topicId,
      quizType: quizType,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      records: records ?? this.records,
      isSubmittingResult: isSubmittingResult ?? this.isSubmittingResult,
      result: result ?? this.result,
      rewardXp: rewardXp ?? this.rewardXp,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      leveledUp: leveledUp ?? this.leveledUp,
    );
  }
}
