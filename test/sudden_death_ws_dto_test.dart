import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/core/network/dtos/quiz_dtos.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/quiz/data/models/sudden_death_ws_dto.dart';

void main() {
  group('Sudden Death Inbound Messages (Client -> Server)', () {
    test('join_game serialization with session', () {
      final msg = WsInboundMessage.joinGame(session: 'sess-1234');
      final json = msg.toJson();
      expect(json['type'], 'join_game');
      expect(json['data']['session'], 'sess-1234');
    });

    test('join_game serialization without session', () {
      final msg = WsInboundMessage.joinGame();
      final json = msg.toJson();
      expect(json['type'], 'join_game');
      expect(json['data'].containsKey('session'), isFalse);
    });

    test('submit_answer serialization with all fields', () {
      final msg = WsInboundMessage.submitAnswer(
        question: 'ACC001',
        option: 'b',
        selectedText: 'Accounts Payable',
        timeTakenMs: 2500,
        session: 'sess-1234',
      );
      final json = msg.toJson();
      expect(json['type'], 'submit_answer');
      expect(json['data']['question'], 'ACC001');
      expect(json['data']['option'], 'b');
      expect(json['data']['selected_text'], 'Accounts Payable');
      expect(json['data']['time_taken_ms'], 2500);
      expect(json['data']['session'], 'sess-1234');
    });

    test('submit_answer serialization with skip option', () {
      final msg = WsInboundMessage.submitAnswer(
        question: 'ACC002',
        option: 'skip',
        timeTakenMs: 1500,
      );
      final json = msg.toJson();
      expect(json['type'], 'submit_answer');
      expect(json['data']['question'], 'ACC002');
      expect(json['data']['option'], 'skip');
      expect(json['data'].containsKey('selected_text'), isFalse);
    });

    test('use_power_up serialization for fifty_fifty', () {
      final msg = WsInboundMessage.usePowerUp(
        question: 'ACC001',
        powerUp: 'fifty_fifty',
        session: 'sess-1234',
      );
      final json = msg.toJson();
      expect(json['type'], 'use_power_up');
      expect(json['data']['question'], 'ACC001');
      expect(json['data']['power_up'], 'fifty_fifty');
      expect(json['data']['session'], 'sess-1234');
    });

    test('use_power_up serialization for authoritative add_time', () {
      final msg = WsInboundMessage.usePowerUp(
        question: 'ACC001',
        powerUp: 'add_time',
        session: 'sess-1234',
      );
      final json = msg.toJson();
      expect(json['type'], 'use_power_up');
      expect(json['data']['question'], 'ACC001');
      expect(json['data']['power_up'], 'add_time');
      expect(json['data']['session'], 'sess-1234');
    });
  });

  group('Sudden Death Outbound Messages (Server -> Client)', () {
    test('WsQuestionPayload deserialization and domain conversion', () {
      const rawJson = '''
      {
        "question": "ACC001",
        "prompt": "Which of the following is a liability?",
        "points": 10,
        "hint": "Obligation to pay in future",
        "options": [
          {"option": "a", "text": "Cash"},
          {"option": "b", "text": "Accounts Payable"},
          {"option": "c", "text": "Inventory"},
          {"option": "d", "text": "Building"}
        ],
        "time_limit_ms": 15000,
        "remaining_time_ms": 9500,
        "add_time_used": true,
        "question_number": 1,
        "total_questions": 5
      }
      ''';

      final payload = WsQuestionPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.question, 'ACC001');
      expect(payload.prompt, 'Which of the following is a liability?');
      expect(payload.points, 10);
      expect(payload.hint, 'Obligation to pay in future');
      expect(payload.options.length, 4);
      expect(payload.options[0].option, 'a');
      expect(payload.options[0].text, 'Cash');
      expect(payload.timeLimitMs, 15000);
      expect(payload.remainingTimeMs, 9500);
      expect(payload.addTimeUsed, isTrue);
      expect(payload.questionNumber, 1);
      expect(payload.totalQuestions, 5);

      final domain = payload.toDomain('accounting');
      expect(domain, isA<SuddenDeathQuestion>());
      expect(domain.id, 'ACC001');
      expect(domain.topicId, 'accounting');
      expect(domain.options.length, 4);
      expect(domain.options[1].id, 'b');
      expect(domain.options[1].text, 'Accounts Payable');
      expect(
        domain.correctOptionId,
        isEmpty,
      ); // Correct option hidden server-side
    });

    test('WsAnswerResultPayload deserialization for correct answer', () {
      const rawJson = '''
      {
        "question": "ACC001",
        "option": "b",
        "correct_option": "b",
        "is_correct": true,
        "is_skipped": false,
        "explanation": "Accounts Payable is a current liability.",
        "points_earned": 10,
        "coins_earned": 0,
        "your_score": 10,
        "is_timeout": false
      }
      ''';

      final payload = WsAnswerResultPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.question, 'ACC001');
      expect(payload.option, 'b');
      expect(payload.correctOption, 'b');
      expect(payload.isCorrect, isTrue);
      expect(payload.isSkipped, isFalse);
      expect(payload.explanation, 'Accounts Payable is a current liability.');
      expect(payload.pointsEarned, 10);
      expect(payload.yourScore, 10);
      expect(payload.isTimeout, isFalse);
    });

    test('WsAnswerResultPayload deserialization for timeout', () {
      const rawJson = '''
      {
        "question": "ACC002",
        "option": "timeout",
        "correct_option": "c",
        "is_correct": false,
        "is_skipped": false,
        "explanation": "Time expired.",
        "points_earned": 0,
        "coins_earned": 0,
        "your_score": 10,
        "is_timeout": true
      }
      ''';

      final payload = WsAnswerResultPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.question, 'ACC002');
      expect(payload.option, 'timeout');
      expect(payload.correctOption, 'c');
      expect(payload.isCorrect, isFalse);
      expect(payload.isTimeout, isTrue);
    });

    test('WsPowerUpResultPayload deserialization', () {
      const rawJson = '''
      {
        "question": "ACC001",
        "hidden_options": ["a", "d"]
      }
      ''';

      final payload = WsPowerUpResultPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.question, 'ACC001');
      expect(payload.hiddenOptions, ['a', 'd']);
    });

    test('WsPowerUpResultPayload parses authoritative add_time result', () {
      const rawJson = '''
      {
        "question": "ACC001",
        "power_up": "add_time",
        "added_time_ms": 5000,
        "remaining_time_ms": 9200
      }
      ''';

      final payload = WsPowerUpResultPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.question, 'ACC001');
      expect(payload.powerUp, 'add_time');
      expect(payload.addedTimeMs, 5000);
      expect(payload.remainingTimeMs, 9200);
      expect(payload.hiddenOptions, isEmpty);
    });

    test('WsGameOverPayload deserialization and conversion to QuizResult', () {
      const rawJson = '''
      {
        "final_score": 20,
        "total_questions": 3,
        "correct_count": 2,
        "coins_earned": 11,
        "xp_earned": 25,
        "gems_earned": 1,
        "new_level": 2,
        "did_level_up": true,
        "level_up_reward": {
          "coins": 50,
          "xp": 0,
          "gems": 1
        }
      }
      ''';

      final payload = WsGameOverPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.finalScore, 20);
      expect(payload.totalQuestions, 3);
      expect(payload.correctCount, 2);
      expect(payload.coinsEarned, 11);
      expect(payload.xpEarned, 25);
      expect(payload.gemsEarned, 1);
      expect(payload.newLevel, 2);
      expect(payload.didLevelUp, isTrue);
      expect(payload.levelUpReward, isNotNull);
      expect(payload.levelUpReward!.coins, 50);

      final started = DateTime.now().subtract(const Duration(seconds: 40));
      final completed = DateTime.now();

      final result = payload.toQuizResult(
        sessionId: 'sess-1234',
        userId: 'user-001',
        topicId: 'accounting',
        startedAt: started,
        completedAt: completed,
      );

      expect(result.sessionId, 'sess-1234');
      expect(result.score.earnedPoints, 20);
      expect(result.score.correctCount, 2);
      expect(result.score.totalCount, 3);
      expect(result.coinsAwarded, 11);
      expect(result.xpAwarded, 25);
      expect(result.gemsAwarded, 1);
      expect(result.didLevelUp, isTrue);
      expect(result.quizType, QuestionType.suddenDeath);
    });

    test('WsErrorPayload deserialization with machine-readable code', () {
      const rawJson = '''
      {
        "code": "stale_answer",
        "message": "stale answer: current question is ACC002"
      }
      ''';

      final payload = WsErrorPayload.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(payload.code, 'stale_answer');
      expect(payload.message, 'stale answer: current question is ACC002');
    });

    test('WsServerEvent factory parses all polymorphic event frames', () {
      final qEvent = WsServerEvent.fromJson({
        'type': 'question',
        'data': {
          'question': 'Q1',
          'prompt': 'Prompt 1',
          'points': 10,
          'options': [],
          'time_limit_ms': 15000,
          'remaining_time_ms': 15000,
          'question_number': 1,
          'total_questions': 3,
        },
      });
      expect(qEvent, isA<WsQuestionEvent>());
      expect((qEvent as WsQuestionEvent).payload.question, 'Q1');

      final aEvent = WsServerEvent.fromJson({
        'type': 'answer_result',
        'data': {
          'question': 'Q1',
          'option': 'a',
          'correct_option': 'a',
          'is_correct': true,
          'is_skipped': false,
          'points_earned': 10,
          'coins_earned': 0,
          'your_score': 10,
          'is_timeout': false,
        },
      });
      expect(aEvent, isA<WsAnswerResultEvent>());

      final pEvent = WsServerEvent.fromJson({
        'type': 'power_up_result',
        'data': {
          'question': 'Q1',
          'hidden_options': ['b', 'c'],
        },
      });
      expect(pEvent, isA<WsPowerUpResultEvent>());

      final gEvent = WsServerEvent.fromJson({
        'type': 'game_over',
        'data': {
          'final_score': 10,
          'total_questions': 1,
          'correct_count': 1,
          'coins_earned': 5,
          'xp_earned': 10,
          'gems_earned': 0,
          'new_level': 1,
          'did_level_up': false,
        },
      });
      expect(gEvent, isA<WsGameOverEvent>());

      final eEvent = WsServerEvent.fromJson({
        'type': 'error',
        'data': {
          'code': 'power_up_already_used',
          'message': 'fifty_fifty already used',
        },
      });
      expect(eEvent, isA<WsErrorEvent>());
      expect((eEvent as WsErrorEvent).payload.code, 'power_up_already_used');
    });

    group('game_over elimination signalling', () {
      WsGameOverPayload parse(Map<String, dynamic> data) =>
          WsGameOverPayload.fromJson(data);

      test('parses game_mode, end_reason and ended_early', () {
        final payload = parse({
          'final_score': 20,
          'total_questions': 10,
          'correct_count': 2,
          'coins_earned': 3,
          'xp_earned': 30,
          'gems_earned': 0,
          'new_level': 2,
          'did_level_up': true,
          'game_mode': 'sudden_death',
          'end_reason': 'eliminated',
          'ended_early': true,
        });

        expect(payload.gameMode, 'sudden_death');
        expect(payload.endReason, 'eliminated');
        expect(payload.endedEarly, isTrue);
        expect(payload.wasEliminated, isTrue);
        expect(payload.wasCleared, isFalse);
      });

      test('a cleared run is not an elimination', () {
        final payload = parse({
          'final_score': 100,
          'total_questions': 10,
          'correct_count': 10,
          'coins_earned': 5,
          'xp_earned': 50,
          'gems_earned': 0,
          'new_level': 1,
          'did_level_up': false,
          'game_mode': 'sudden_death',
          'end_reason': 'cleared',
          'ended_early': false,
        });

        expect(payload.wasCleared, isTrue);
        expect(payload.wasEliminated, isFalse);
      });

      // A completed MCQ run can have fewer correct answers than questions
      // without ever being eliminated, so the server flag must win over the
      // score heuristic.
      test('server verdict beats the score heuristic', () {
        final payload = parse({
          'final_score': 70,
          'total_questions': 10,
          'correct_count': 7,
          'coins_earned': 5,
          'xp_earned': 70,
          'gems_earned': 0,
          'new_level': 1,
          'did_level_up': false,
          'game_mode': 'mcq',
          'end_reason': 'cleared',
          'ended_early': false,
        });

        // 7 < 10 would look like an early exit, but the run completed.
        expect(payload.wasEliminated, isFalse);
        final result = payload.toQuizResult(
          sessionId: 's1',
          topicId: 'accounting',
          startedAt: DateTime(2026),
          completedAt: DateTime(2026),
        );
        expect(result.endedEarly, isFalse);
      });

      test('falls back to the heuristic when ended_early is absent', () {
        final payload = parse({
          'final_score': 20,
          'total_questions': 10,
          'correct_count': 2,
          'coins_earned': 0,
          'xp_earned': 20,
          'gems_earned': 0,
          'new_level': 1,
          'did_level_up': false,
        });

        expect(payload.endedEarly, isNull);
        expect(payload.wasEliminated, isTrue);
        // Absent field falls back to a safe default rather than throwing.
        expect(payload.gameMode, 'mcq');
        expect(payload.endReason, '');
      });

      test('an eliminated run reports endedEarly on the quiz result', () {
        final payload = parse({
          'final_score': 20,
          'total_questions': 10,
          'correct_count': 2,
          'coins_earned': 0,
          'xp_earned': 20,
          'gems_earned': 0,
          'new_level': 1,
          'did_level_up': false,
          'game_mode': 'sudden_death',
          'end_reason': 'eliminated',
          'ended_early': true,
        });

        final result = payload.toQuizResult(
          sessionId: 's1',
          topicId: 'accounting',
          startedAt: DateTime(2026),
          completedAt: DateTime(2026),
        );
        expect(result.endedEarly, isTrue);
      });
    });

    group('create session game mode', () {
      test('request omits game_mode when not provided', () {
        const dto = CreateSessionRequestDto(topic: 'accounting');
        expect(dto.toJson().containsKey('game_mode'), isFalse);
      });

      test('request serializes sudden_death', () {
        const dto = CreateSessionRequestDto(
          topic: 'accounting',
          gameMode: 'sudden_death',
        );
        expect(dto.toJson()['game_mode'], 'sudden_death');
      });

      test('response defaults to mcq when the server omits the mode', () {
        final dto = SessionCreatedResponseDto.fromJson({
          'session': 'abc',
          'topic': 'accounting',
          'total_questions': 10,
          'time_limit_sec': 15,
          'questions': <Map<String, dynamic>>[],
        });
        expect(dto.gameMode, 'mcq');
      });

      test('response exposes the persisted mode', () {
        final dto = SessionCreatedResponseDto.fromJson({
          'session': 'abc',
          'topic': 'accounting',
          'total_questions': 10,
          'time_limit_sec': 15,
          'questions': <Map<String, dynamic>>[],
          'game_mode': 'sudden_death',
        });
        expect(dto.gameMode, 'sudden_death');
      });
    });
  });
}
