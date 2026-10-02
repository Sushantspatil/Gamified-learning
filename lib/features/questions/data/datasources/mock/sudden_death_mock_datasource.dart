import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:skillverse_app/app/config/app_config.dart';
import '../../../domain/entities/question.dart';
import '../../models/question_dto.dart';

/// Dedicated mock datasource for Sudden Death development questions.
///
/// Loads the 10 dedicated Book-Keeping & Accountancy questions from
/// [assets/mock/sudden_death_questions.json]. This datasource is strictly
/// isolated to development, testing, and UI preview; it is never used as
/// a production fallback.
class SuddenDeathMockDatasource {
  static const String assetPath = 'assets/mock/sudden_death_questions.json';

  final AssetBundle? _bundle;

  const SuddenDeathMockDatasource({AssetBundle? bundle}) : _bundle = bundle;

  /// Whether Sudden Death development questions are available for preview.
  bool get isSuddenDeathDevelopmentAvailable =>
      AppConfig.developmentPreviewsEnabled;

  /// Loads and parses the 10 dedicated Sudden Death development questions.
  Future<List<SuddenDeathQuestion>> getDevelopmentQuestions({
    String topicId = 'accounting',
  }) async {
    if (!isSuddenDeathDevelopmentAvailable) return const [];

    // In local development and test runners, read directly from the JSON file on disk
    try {
      final file = File(assetPath);
      if (file.existsSync()) {
        final jsonString = file.readAsStringSync();
        return parseQuestionsFromJson(jsonString, topicId: topicId);
      }
    } catch (_) {}

    final bundle = _bundle;
    if (bundle != null) {
      try {
        final jsonString = await bundle.loadString(assetPath);
        return parseQuestionsFromJson(jsonString, topicId: topicId);
      } catch (_) {}
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return parseQuestionsFromJson(jsonString, topicId: topicId);
    } catch (_) {
      // Fallback to embedded copy if asset bundle is unavailable
      return getBundledQuestions(topicId: topicId);
    }
  }

  /// Synchronously returns the 10 dedicated development questions for tests
  /// that run without Flutter asset bundle initialization.
  List<SuddenDeathQuestion> getBundledQuestions({
    String topicId = 'accounting',
  }) {
    return parseQuestionsFromJson(bundledRawJson, topicId: topicId);
  }

  /// Parses and validates Sudden Death questions from JSON string.
  static List<SuddenDeathQuestion> parseQuestionsFromJson(
    String jsonString, {
    String topicId = 'accounting',
  }) {
    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object at root');
    }

    final responseDto = SuddenDeathQuestionsResponseDto.fromJson(decoded);
    validateQuestions(responseDto.questions);

    return responseDto.questions
        .map((dto) => dto.toDomain(topicId: topicId))
        .toList(growable: false);
  }

  /// Validates the 10 dedicated development questions against contract rules.
  static void validateQuestions(List<SuddenDeathQuestionDto> questions) {
    if (questions.length != 10) {
      throw FormatException(
        'Expected exactly 10 Sudden Death questions, found ${questions.length}',
      );
    }

    final seenIds = <String>{};
    final seenQuestions = <String>{};
    var easyCount = 0;
    var mediumCount = 0;
    var hardCount = 0;

    for (final q in questions) {
      if (q.id.isEmpty) {
        throw const FormatException('Question ID cannot be empty');
      }
      if (!seenIds.add(q.id)) {
        throw FormatException('Duplicate question ID detected: ${q.id}');
      }

      final normalizedPrompt = (q.prompt.isNotEmpty ? q.prompt : q.question)
          .trim()
          .toLowerCase();
      if (!seenQuestions.add(normalizedPrompt)) {
        throw FormatException('Duplicate question text detected: ${q.id}');
      }

      if (q.questionType != 'sudden_death') {
        throw FormatException(
          'Invalid question_type for ${q.id}: expected sudden_death, got ${q.questionType}',
        );
      }

      if (q.options.length != 4) {
        throw FormatException(
          'Question ${q.id} must have exactly 4 options, found ${q.options.length}',
        );
      }

      final optionIds = q.options.map((o) => o.option).toSet();
      if (optionIds.length != 4) {
        throw FormatException(
          'Question ${q.id} contains duplicate option identifiers',
        );
      }

      if (!optionIds.contains(q.correctOption)) {
        throw FormatException(
          'Question ${q.id} correct_option (${q.correctOption}) does not reference any valid option ($optionIds)',
        );
      }

      switch (q.difficulty?.toLowerCase()) {
        case 'easy':
          easyCount++;
          break;
        case 'medium':
          mediumCount++;
          break;
        case 'hard':
          hardCount++;
          break;
        default:
          throw FormatException(
            'Question ${q.id} has invalid difficulty: ${q.difficulty}',
          );
      }
    }

    if (easyCount != 4 || mediumCount != 4 || hardCount != 2) {
      throw FormatException(
        'Expected difficulty distribution 4 easy / 4 medium / 2 hard, but found $easyCount easy / $mediumCount medium / $hardCount hard',
      );
    }
  }

  /// Bundled copy of the exact same JSON content in assets/mock/sudden_death_questions.json.
  /// Used for offline test safety when asset bundles are not loaded.
  static const String bundledRawJson = r'''{
  "game_mode": "sudden_death",
  "subject": "Book-Keeping & Accountancy",
  "total": 10,
  "time_limit_sec": 15,
  "questions": [
    {
      "id": "sd_acc_001",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Which account is debited when goods are purchased for cash?",
      "prompt": "Which account is debited when goods are purchased for cash?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Purchases Account"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Cash Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Sales Account"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Capital Account"
        }
      ],
      "correct_option": "a",
      "difficulty": "easy",
      "hint": "Think about which account records goods bought for resale."
    },
    {
      "id": "sd_acc_002",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "What type of account is Cash Account?",
      "prompt": "What type of account is Cash Account?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Personal Account"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Real Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Nominal Account"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Valuation Account"
        }
      ],
      "correct_option": "b",
      "difficulty": "easy",
      "hint": "Tangible business assets are classified under this rule."
    },
    {
      "id": "sd_acc_003",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Which golden rule states 'Debit the receiver, Credit the giver'?",
      "prompt": "Which golden rule states 'Debit the receiver, Credit the giver'?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Nominal Account"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Real Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Personal Account"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Representative Account"
        }
      ],
      "correct_option": "c",
      "difficulty": "easy",
      "hint": "This rule applies to persons, firms, and institutions."
    },
    {
      "id": "sd_acc_004",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "What is the primary book of original entry called?",
      "prompt": "What is the primary book of original entry called?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Ledger"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Journal"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Trial Balance"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Balance Sheet"
        }
      ],
      "correct_option": "b",
      "difficulty": "easy",
      "hint": "Transactions are recorded here chronologically first."
    },
    {
      "id": "sd_acc_005",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "When rent is paid in cash, which account is credited?",
      "prompt": "When rent is paid in cash, which account is credited?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Rent Account"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Landlord Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Cash Account"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Outstanding Rent Account"
        }
      ],
      "correct_option": "c",
      "difficulty": "medium",
      "hint": "Credit what goes out of the business."
    },
    {
      "id": "sd_acc_006",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Depreciation charged on machinery is debited to which account?",
      "prompt": "Depreciation charged on machinery is debited to which account?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Machinery Account"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Depreciation Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Cash Account"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Provision Account"
        }
      ],
      "correct_option": "b",
      "difficulty": "medium",
      "hint": "Debit all expenses and losses under the nominal rule."
    },
    {
      "id": "sd_acc_007",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Which statement verifies the arithmetical accuracy of ledger accounts?",
      "prompt": "Which statement verifies the arithmetical accuracy of ledger accounts?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Balance Sheet"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Profit & Loss Account"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Trial Balance"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Cash Flow Statement"
        }
      ],
      "correct_option": "c",
      "difficulty": "medium",
      "hint": "It lists debit and credit totals before final accounts."
    },
    {
      "id": "sd_acc_008",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Goods returned by a customer are recorded in which book?",
      "prompt": "Goods returned by a customer are recorded in which book?",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Purchases Returns Book"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Sales Returns Book"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Journal Proper"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Cash Book"
        }
      ],
      "correct_option": "b",
      "difficulty": "medium",
      "hint": "Also known as the return inwards book."
    },
    {
      "id": "sd_acc_009",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "An error of omission occurs when a transaction is:",
      "prompt": "An error of omission occurs when a transaction is:",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Recorded in the wrong subsidiary book"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Completely or partially not recorded"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Posted with inverted debit and credit"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Violating fundamental capital principles"
        }
      ],
      "correct_option": "b",
      "difficulty": "hard",
      "hint": "The transaction was forgotten or left out entirely."
    },
    {
      "id": "sd_acc_010",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "According to the Dual Aspect concept, Total Assets always equal:",
      "prompt": "According to the Dual Aspect concept, Total Assets always equal:",
      "options": [
        {
          "id": "a",
          "option": "a",
          "text": "Capital minus Liabilities"
        },
        {
          "id": "b",
          "option": "b",
          "text": "Total Liabilities plus Capital"
        },
        {
          "id": "c",
          "option": "c",
          "text": "Net Profit plus Drawings"
        },
        {
          "id": "d",
          "option": "d",
          "text": "Gross Revenue minus Expenses"
        }
      ],
      "correct_option": "b",
      "difficulty": "hard",
      "hint": "This forms the fundamental accounting balance sheet equation."
    }
  ]
}''';
}
