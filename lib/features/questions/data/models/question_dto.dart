import '../../domain/entities/question.dart';

class QuestionOptionDto {
  final String option;
  final String text;

  const QuestionOptionDto({required this.option, required this.text});

  factory QuestionOptionDto.fromJson(Map<String, dynamic> json) {
    return QuestionOptionDto(
      option: json['option'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  QuestionOption toDomain() {
    return QuestionOption(
      id: option,
      text: text,
    );
  }
}

class QuestionDto {
  final String question;
  final String prompt;
  final int points;
  final String? hint;
  final List<QuestionOptionDto> options;
  final String? correctOption;

  const QuestionDto({
    required this.question,
    required this.prompt,
    required this.points,
    this.hint,
    required this.options,
    this.correctOption,
  });

  factory QuestionDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return QuestionDto(
      question: json['question']?.toString() ?? '',
      prompt: json['prompt'] as String? ?? '',
      points: json['points'] as int? ?? 10,
      hint: json['hint'] as String?,
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(QuestionOptionDto.fromJson)
          .toList(),
      correctOption: json['correct_option'] as String?,
    );
  }

  McqQuestion toDomain(String topicId) {
    final domainOptions = options.map((o) => o.toDomain()).toList();
    final resolvedCorrectOptionId = correctOption ??
        (domainOptions.isNotEmpty ? domainOptions.first.id : 'a');

    return McqQuestion(
      id: question,
      topicId: topicId,
      prompt: prompt,
      points: points,
      hint: hint,
      correctOptionId: resolvedCorrectOptionId,
      options: domainOptions,
    );
  }
}

class TopicQuestionsResponseDto {
  final String topic;
  final int total;
  final int timeLimitSec;
  final List<QuestionDto> questions;

  const TopicQuestionsResponseDto({
    required this.topic,
    required this.total,
    required this.timeLimitSec,
    required this.questions,
  });

  factory TopicQuestionsResponseDto.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    return TopicQuestionsResponseDto(
      topic: json['topic'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      timeLimitSec: json['time_limit_sec'] as int? ?? 15,
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(QuestionDto.fromJson)
          .toList(),
    );
  }
}

class SuddenDeathQuestionDto {
  final String id;
  final String question;
  final String prompt;
  final String questionType;
  final String? subject;
  final String? topic;
  final String? difficulty;
  final String? hint;
  final String correctOption;
  final List<QuestionOptionDto> options;

  const SuddenDeathQuestionDto({
    required this.id,
    required this.question,
    required this.prompt,
    required this.questionType,
    this.subject,
    this.topic,
    this.difficulty,
    this.hint,
    required this.correctOption,
    required this.options,
  });

  factory SuddenDeathQuestionDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final id = (json['id'] ?? json['question'] ?? '').toString();
    final prompt = (json['prompt'] ?? json['question'] ?? '').toString();
    final questionText = (json['question'] ?? json['prompt'] ?? '').toString();

    return SuddenDeathQuestionDto(
      id: id,
      question: questionText,
      prompt: prompt,
      questionType: json['question_type'] as String? ?? 'sudden_death',
      subject: json['subject'] as String?,
      topic: json['topic'] as String?,
      difficulty: json['difficulty'] as String?,
      hint: json['hint'] as String?,
      correctOption: (json['correct_option'] ?? 'a').toString(),
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map((opt) => QuestionOptionDto(
                option: (opt['id'] ?? opt['option'] ?? '').toString(),
                text: (opt['text'] ?? '').toString(),
              ))
          .toList(),
    );
  }

  SuddenDeathQuestion toDomain({String topicId = 'accounting'}) {
    final domainOptions = options.map((o) => o.toDomain()).toList();
    return SuddenDeathQuestion(
      id: id,
      topicId: topic ?? topicId,
      prompt: prompt.isNotEmpty ? prompt : question,
      points: 20, // Compatibility value for demo rendering, clearly isolated from production scoring
      options: domainOptions,
      correctOptionId: correctOption,
      hint: hint,
      difficulty: difficulty,
    );
  }
}

class SuddenDeathQuestionsResponseDto {
  final String gameMode;
  final String subject;
  final int total;
  final int timeLimitSec;
  final List<SuddenDeathQuestionDto> questions;

  const SuddenDeathQuestionsResponseDto({
    required this.gameMode,
    required this.subject,
    required this.total,
    required this.timeLimitSec,
    required this.questions,
  });

  factory SuddenDeathQuestionsResponseDto.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    return SuddenDeathQuestionsResponseDto(
      gameMode: json['game_mode'] as String? ?? 'sudden_death',
      subject: json['subject'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      timeLimitSec: json['time_limit_sec'] as int? ?? 15,
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(SuddenDeathQuestionDto.fromJson)
          .toList(),
    );
  }
}
