# Frontend Points & Scoring Integration Guide

## 1. Architecture Overview

The Flutter application (`Gamified-learning`) displays the MCQ result returned
by the backend (`GamifiedQuizApp_digitalHQ`). Production Flutter code does not
recalculate or replace backend score, XP, coin, or reward-breakdown totals.

The production flow is:

```text
Flutter submits the answer
Backend evaluates correctness and awards answer points
Flutter completes the session
Backend returns final score, rewards, and breakdowns
Flutter maps and displays that response
```

Mock scoring remains isolated in `QuizMockDatasource` for tests and demo mode.

---

## 2. Deterministic MCQ Rules

The backend applies these rules to MCQ sessions:

```text
Score
Correct answer = 10 points
Wrong answer = 0 points
Skipped answer = 0 points
MCQ score = correct_count × 10
max_score = total_questions × 10

XP
Quiz completion = 10 XP
Each correct answer = 5 XP
Perfect score bonus = 15 XP

Coins
Quiz completion = 5 Coins
Each correct answer = 2 Coins
Perfect score bonus = 10 Coins
```

Response time, difficulty, combo streak, and power-up use do not modify MCQ
score or rewards. Other game modes retain their own independent rules.

---

## 3. Answer Evaluation

`AnswerResultResponseDto` receives the backend-owned correctness and
`points_earned` values. `QuizRemoteDatasource.evaluateAnswer` maps those values
directly into `AnswerEvaluation`; it does not inspect question points or apply a
local multiplier.

`time_taken_ms` may still be sent as answer audit information. It does not
produce an MCQ speed bonus.

---

## 4. Session Completion

`QuizRemoteDatasource.submitSession` calls `POST /quiz/sessions/complete` and
maps the following values from `SessionCompleteResponseDto`:

- `final_score`
- `max_score`
- `correct_count`
- `total_questions`
- `accuracy_percentage`
- `xp_awarded`
- `coins_awarded`
- `gems_awarded`
- `score_breakdown`
- `xp_breakdown`
- `coin_breakdown`
- optional level, streak, and separate level-up reward data

Valid zero totals are authoritative. For example, `final_score: 0` is not
replaced by locally recorded question points. If an older response omits a
breakdown, Flutter displays the returned totals and hides unavailable rows.

---

## 5. Result Presentation

The existing result screen displays backend values without recalculation:

- Score: `earnedPoints / maxPoints`
- Correct and wrong counts from backend totals
- Accuracy from correct count divided by total questions
- XP and coin totals from `xp_awarded` and `coins_awarded`
- Non-zero backend breakdown rows with user-friendly labels
- A level-up reward separately from the base MCQ reward

For a backend result of five correct answers out of ten, the screen displays:

```text
50 / 100
5 correct
5 wrong
50% accuracy
+35 XP
+15 Coins
```

---

## 6. Session Inactivity TTL (5 Minutes)

If a quiz session has been left idle for $> 5\text{ minutes}$ without answering or power-up activity:
1. The backend automatically marks the session as `abandoned`.
2. Any subsequent submission returns `HTTP 409 Conflict`:
   ```json
   {
     "success": false,
     "message": "quiz session expired due to 5 minutes of inactivity and has been abandoned"
   }
   ```
3. `ApiClient` translates this into `ValidationException(message, '409')`.
4. The user is prompted to return to the dashboard and start a fresh quiz attempt.
