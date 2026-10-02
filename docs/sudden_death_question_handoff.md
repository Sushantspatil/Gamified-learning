# Sudden Death Question Handoff Documentation

## Overview
This document specifies the handoff for the **10 dedicated Sudden Death development questions** prepared for frontend UI flow testing in the Flutter application.

- **Game Mode**: `sudden_death`
- **Total Questions**: 10
- **Subject**: Book-Keeping & Accountancy
- **Difficulty Distribution**: 4 Easy, 4 Medium, 2 Hard
- **Timer Target**: 15 seconds per question
- **Source JSON Asset**: `assets/mock/sudden_death_questions.json`

---

## Question Data Schema & Contract

The JSON payload strictly adheres to the following contract:

```json
{
  "game_mode": "sudden_death",
  "subject": "Book-Keeping & Accountancy",
  "total_questions": 10,
  "difficulty_distribution": {
    "easy": 4,
    "medium": 4,
    "hard": 2
  },
  "questions": [
    {
      "id": "sd_acc_001",
      "question_type": "sudden_death",
      "question": "Which account is debited when goods are purchased for cash?",
      "options": [
        {"id": "a", "text": "Purchases Account"},
        {"id": "b", "text": "Cash Account"},
        {"id": "c", "text": "Sales Account"},
        {"id": "d", "text": "Capital Account"}
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
- `question` (`string`): Clear, concise prompt suitable for a 15-second timed response (no long calculations).
- `options` (`list`): Exactly 4 options (`a`, `b`, `c`, `d`).
- `correct_option` (`string`): The id of the single authoritative correct option.
- `difficulty` (`string`): One of `easy`, `medium`, or `hard`.
- `hint` (`string`): Contextual hint used by the Hint power-up.

---

## Question Breakdown

| ID | Difficulty | Topic / Concept | Correct Option | Summary |
|---|---|---|---|---|
| `sd_acc_001` | easy | Basic Journal Entry | `a` | Purchases Account debited when goods purchased for cash |
| `sd_acc_002` | easy | Financial Statements | `c` | Balance Sheet is a statement of financial position, not an account |
| `sd_acc_003` | easy | Golden Rules of Accounting | `b` | Debit the receiver, credit the giver applies to Personal Accounts |
| `sd_acc_004` | easy | Trial Balance | `c` | Ledger balances are checked for arithmetical accuracy via Trial Balance |
| `sd_acc_005` | medium | Bank Reconciliation Statement | `a` | Cheques deposited but not cleared are deducted from passbook balance |
| `sd_acc_006` | medium | Capital vs Revenue Expenditure | `c` | Heavy advertising campaign is Deferred Revenue Expenditure |
| `sd_acc_007` | medium | Accounting Principles | `b` | Prudence/Conservatism principle: Anticipate no profit, provide for all losses |
| `sd_acc_008` | medium | Depreciation | `d` | Reducing Balance method: depreciation decreases every year |
| `sd_acc_009` | hard | Error Rectification | `b` | Error of Commission: posting to wrong account of same class |
| `sd_acc_010` | hard | Partnership / Goodwill | `a` | Sacrificing Ratio: Old Share minus New Share on admission |

---

## Critical Backend Responsibilities

1. **Import & Isolation**:
   - Import/map these questions with `question_type = sudden_death`.
   - **Do not mix or pool them into MCQ questions.**
2. **Content-Only Source**:
   - The JSON contains **question content only**. It intentionally omits points, streaks, XP, or Coins.
3. **Backend-Authoritative Logic**:
   - **Correctness validation**: Backend verifies selected option.
   - **Authoritative Scoring**: Backend determines XP, Coins, base score, and streak multipliers.
   - **Timer & Timeout**: Backend authoritatively validates 15-second window expiration.
   - **Power-Ups**: Backend handles Skip actions, 50:50 excluded options, and time extensions.
   - **Session Termination & Completion**: Backend declares elimination on first mistake/timeout and marks full completion when surviving all 10 questions.
