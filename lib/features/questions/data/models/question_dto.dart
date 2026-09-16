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
