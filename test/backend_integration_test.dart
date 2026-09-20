import 'package:flutter_test/flutter_test.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/features/questions/data/models/question_dto.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';

void main() {
  group('Backend DTO Parsing', () {
    test('parses Go backend TopicQuestionsResponse correctly', () {
      final json = {
        'topic': 'accounting',
        'total': 2,
        'time_limit_sec': 15,
        'questions': [
          {
            'question': '1',
            'prompt': 'Book-keeping means:',
            'points': 10,
            'hint': 'Clerical record keeping.',
            'options': [
              {'option': 'a', 'text': 'Recording business transactions'},
              {'option': 'b', 'text': 'Auditing accounts'},
              {'option': 'c', 'text': 'Preparing budgets'},
              {'option': 'd', 'text': 'Paying taxes'},
            ],
            'correct_option': 'a',
          },
          {
            'question': '2',
            'prompt': 'A person who owns a business is called:',
            'points': 10,
            'options': [
              {'option': 'a', 'text': 'Debtor'},
              {'option': 'b', 'text': 'Creditor'},
              {'option': 'c', 'text': 'Proprietor'},
              {'option': 'd', 'text': 'Customer'},
            ],
            'correct_option': 'c',
          },
        ],
      };

      final responseDto = TopicQuestionsResponseDto.fromJson(json);
      expect(responseDto.topic, 'accounting');
      expect(responseDto.total, 2);
      expect(responseDto.timeLimitSec, 15);
      expect(responseDto.questions.length, 2);

      final q1 = responseDto.questions[0].toDomain('accounting');
      expect(q1.id, '1');
      expect(q1.topicId, 'accounting');
      expect(q1.prompt, 'Book-keeping means:');
      expect(q1.points, 10);
      expect(q1.hint, 'Clerical record keeping.');
      expect(q1.correctOptionId, 'a');
      expect(q1.options.length, 4);
      expect(q1.options[0].id, 'a');
      expect(q1.options[0].text, 'Recording business transactions');
      expect(q1.type, QuestionType.mcq);

      final q2 = responseDto.questions[1].toDomain('accounting');
      expect(q2.id, '2');
      expect(q2.correctOptionId, 'c');
      expect(q2.hint, isNull);
    });
  });

  group('ApiConfig Host Resolution', () {
    test('defaultConfig produces valid base URL and WebSocket URL for local dev', () {
      final config = ApiConfig.defaultConfig();
      expect(
        config.baseUrl,
        'http://localhost:8080/api/v1',
      );
      expect(config.baseUrl.startsWith('http://'), isTrue);
      expect(
        config.rootUrl,
        'http://localhost:8080',
      );
      expect(
        config.wsRootUrl,
        'ws://localhost:8080',
      );
      expect(config.wsRootUrl.startsWith('ws://'), isTrue);
      expect(
        config.gameWsUrl,
        'ws://localhost:8080/ws/game',
      );
      expect(config.gameWsUrl.startsWith('ws://'), isTrue);
    });

    test('customBaseUrl overrides default host', () {
      final config = ApiConfig.defaultConfig(
        customBaseUrl: 'https://custom-backend.up.railway.app/api/v1',
      );
      expect(config.baseUrl, 'https://custom-backend.up.railway.app/api/v1');
      expect(config.wsRootUrl, 'wss://custom-backend.up.railway.app');
      expect(config.gameWsUrl, 'wss://custom-backend.up.railway.app/ws/game');
    });

    test('remote customBaseUrl with http is upgraded to https and wss', () {
      final config = ApiConfig.defaultConfig(
        customBaseUrl: 'http://custom-backend.up.railway.app/api/v1',
      );
      expect(config.baseUrl.startsWith('https://'), isTrue);
      expect(config.wsRootUrl.startsWith('wss://'), isTrue);
      expect(config.gameWsUrl.startsWith('wss://'), isTrue);
    });

    test('localhost customBaseUrl retains plain http and ws', () {
      final config = ApiConfig.defaultConfig(
        customBaseUrl: 'http://localhost:8080/api/v1',
      );
      expect(config.baseUrl, 'http://localhost:8080/api/v1');
      expect(config.wsRootUrl, 'ws://localhost:8080');
      expect(config.gameWsUrl, 'ws://localhost:8080/ws/game');
    });

    test('localhost without scheme normalizes to valid http URL with /api/v1', () {
      final config = ApiConfig.defaultConfig(
        customBaseUrl: 'localhost:8080',
      );
      expect(
        config.baseUrl,
        'http://localhost:8080/api/v1',
      );
      expect(config.baseUrl.startsWith('http://'), isTrue);
      expect(
        config.gameWsUrl,
        'ws://localhost:8080/ws/game',
      );
      expect(config.gameWsUrl.startsWith('ws://'), isTrue);
    });
  });
}
