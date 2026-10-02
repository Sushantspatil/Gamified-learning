# Sudden Death Question Handoff Documentation

## Overview
This document specifies the handoff for the **10 dedicated Sudden Death development questions** prepared for the Flutter application.

- **Game Mode**: `sudden_death`
- **Total Questions**: 10
- **Options Per Question**: Exactly 2 options (`a` and `b`)
- **Subject**: Book-Keeping & Accountancy
- **Difficulty Distribution**: 4 Easy, 4 Medium, 2 Hard
- **Timer Target**: 15 seconds per question
- **Source JSON Asset**: `assets/mock/sudden_death_questions.json`

---

## Important Architecture Difference from MCQ

Sudden Death differs fundamentally from MCQ:
1. **2 Options Only**: Every Sudden Death question presents exactly 2 choices (1 correct, 1 plausible distractor).
2. **50:50 Power-Up**: In a 2-option scenario, 50:50 is not applicable (removing 1 distractor would immediately reveal the answer). The frontend keeps 50:50 disabled for 2-option questions.
3. **No MCQ Sharing**: Sudden Death questions must **never** be pooled or mixed into 4-option MCQ questions.

---

## Question Data Schema & Contract

The JSON payload strictly adheres to the following contract:

```json
{
  "game_mode": "sudden_death",
  "subject": "Book-Keeping & Accountancy",
  "total": 10,
  "time_limit_sec": 15,
  "difficulty_distribution": {
    "easy": 4,
    "medium": 4,
    "hard": 2
  },
  "questions": [
    {
      "id": "sd_acc_001",
      "question_type": "sudden_death",
      "subject": "Book-Keeping & Accountancy",
      "topic": "accounting",
      "question": "Which account is debited when goods are purchased for cash?",
      "prompt": "Which account is debited when goods are purchased for cash?",
      "options": [
        {"id": "a", "option": "a", "text": "Purchases Account"},
        {"id": "b", "option": "b", "text": "Cash Account"}
      ],
      "correct_option": "a",
      "difficulty": "easy",
      "hint": "Think about which account records goods bought for resale."
    }
  ]
}
```

### Field Definitions
- `id` (`string`): Unique question identifier (`sd_acc_001` through `sd_acc_010`).
- `question_type` (`string`): Always `sudden_death`. Must be kept strictly isolated from standard MCQ questions (`mcq`).
- `question` / `prompt` (`string`): Clear, concise prompt suitable for a 15-second timed response (no long calculations).
- `options` (`list`): Exactly 2 options (`a` and `b`).
- `correct_option` (`string`): The id of the single authoritative correct option (`a` or `b`).
- `difficulty` (`string`): One of `easy`, `medium`, or `hard`.
- `hint` (`string`): Contextual hint used by the Hint power-up.

---

## Question Breakdown (10 Questions, 2 Options Each)

| ID | Difficulty | Topic / Concept | Options (a / b) | Correct Option |
|---|---|---|---|---|
| `sd_acc_001` | easy | Basic Journal Entry | `a`: Purchases Account<br>`b`: Cash Account | `a` |
| `sd_acc_002` | easy | Account Classification | `a`: Real Account<br>`b`: Personal Account | `a` |
| `sd_acc_003` | easy | Golden Rules of Accounting | `a`: Real Account<br>`b`: Personal Account | `b` |
| `sd_acc_004` | easy | Books of Original Entry | `a`: Journal<br>`b`: Ledger | `a` |
| `sd_acc_005` | medium | Cash Transactions | `a`: Rent Account<br>`b`: Cash Account | `b` |
| `sd_acc_006` | medium | Depreciation Accounting | `a`: Depreciation Account<br>`b`: Machinery Account | `a` |
| `sd_acc_007` | medium | Trial Balance | `a`: Balance Sheet<br>`b`: Trial Balance | `b` |
| `sd_acc_008` | medium | Subsidiary Books | `a`: Sales Returns Book<br>`b`: Purchases Returns Book | `a` |
| `sd_acc_009` | hard | Error of Omission | `a`: Recorded in the wrong subsidiary book<br>`b`: Completely or partially not recorded | `b` |
| `sd_acc_010` | hard | Accounting Equation | `a`: Total Liabilities plus Capital<br>`b`: Capital minus Liabilities | `a` |

---

## APK Testing Flag

To build and test the development Sudden Death flow on physical devices with release APK builds:

```bash
flutter build apk --release --dart-define=ENABLE_SUDDEN_DEATH_MOCK=true
```

In standard production builds without this flag, mock data is completely disabled and Sudden Death remains backend-dependent.

---

## Critical Backend Responsibilities

1. **Import & Isolation**:
   - Import/map these questions with `question_type = sudden_death`.
   - **Do not mix or pool them into MCQ questions.**
2. **Content-Only Source**:
   - The JSON contains **question content only**. It intentionally omits points, streaks, XP, or Coins.
3. **Backend-Authoritative Logic**:
   - **Correctness validation**: Backend verifies selected option (`a` or `b`).
   - **Authoritative Scoring**: Backend determines XP, Coins, base score, and streak multipliers.
   - **Timer & Timeout**: Backend authoritatively validates 15-second window expiration.
   - **Power-Ups**: Backend handles Skip actions and time extensions (+5 SEC).
   - **Session Termination & Completion**: Backend declares elimination on first mistake/timeout and marks full completion when surviving all 10 questions.
