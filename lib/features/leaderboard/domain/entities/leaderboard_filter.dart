import 'package:equatable/equatable.dart';

import '../../../questions/domain/entities/question.dart';

enum LeaderboardTimeRange { daily, weekly, monthly, allTime }

enum LeaderboardScope { global, school, friends }

class LeaderboardFilter extends Equatable {
  final QuestionType? quizType;
  final String? subjectId;
  final LeaderboardTimeRange timeRange;
  final LeaderboardScope scope;

  const LeaderboardFilter({
    this.quizType,
    this.subjectId,
    this.timeRange = LeaderboardTimeRange.weekly,
    this.scope = LeaderboardScope.global,
  });

  LeaderboardFilter copyWith({
    QuestionType? quizType,
    bool clearQuizType = false,
    String? subjectId,
    bool clearSubjectId = false,
    LeaderboardTimeRange? timeRange,
    LeaderboardScope? scope,
  }) {
    return LeaderboardFilter(
      quizType: clearQuizType ? null : quizType ?? this.quizType,
      subjectId: clearSubjectId ? null : subjectId ?? this.subjectId,
      timeRange: timeRange ?? this.timeRange,
      scope: scope ?? this.scope,
    );
  }

  @override
  List<Object?> get props => [quizType, subjectId, timeRange, scope];
}

extension LeaderboardTimeRangeX on LeaderboardTimeRange {
  String get label {
    return switch (this) {
      LeaderboardTimeRange.daily => 'Daily',
      LeaderboardTimeRange.weekly => 'Weekly',
      LeaderboardTimeRange.monthly => 'Monthly',
      LeaderboardTimeRange.allTime => 'All Time',
    };
  }
}

extension LeaderboardScopeX on LeaderboardScope {
  String get label {
    return switch (this) {
      LeaderboardScope.global => 'Global',
      LeaderboardScope.school => 'School',
      LeaderboardScope.friends => 'Friends',
    };
  }
}
