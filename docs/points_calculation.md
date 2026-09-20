# Frontend Points & Scoring Integration Guide

## 1. Architecture Overview

The Flutter application (`Gamified-learning`) integrates with the server-authoritative scoring engine in `GamifiedQuizApp_digitalHQ`. 

The scoring system provides dynamic, gamified rewards for correct answers using the `CalculatePoints` algorithm:
$$\text{Points} = \text{round}(\text{basePoints} \times \text{difficultyMultiplier} \times \text{speedFactor} \times \text{comboMultiplier})$$

---

## 2. Dynamic Speed Tracking

To ensure the backend speed bonus ($1.5\times$ for $< 50\%$ time, $1.25\times$ for $< 75\%$ time) is real and earned rather than static:

1. In [quiz_remote_datasource.dart](file:///Users/omkargeedh/Developer/Gamified%20Quiz%20App/Gamified-learning/lib/features/quiz/data/datasources/remote/quiz_remote_datasource.dart), `_questionStartTime` is initialized when the session begins (`createSession`).
2. When the user taps an option and `evaluateAnswer` is called:
   ```dart
   final now = DateTime.now();
   var timeTakenMs = 3000;
   if (_questionStartTime != null) {
     timeTakenMs = now.difference(_questionStartTime!).inMilliseconds;
     if (timeTakenMs < 500) timeTakenMs = 500;
     if (timeTakenMs > 15000) timeTakenMs = 15000;
   }
   _questionStartTime = now;
   ```
3. The precise millisecond duration is packaged into `EvaluateAnswerRequestDto` and evaluated by the backend against the 15-second question time limit.

---

## 3. Answer Evaluation & Score Persistence

When the backend grades an answer, `AnswerResultResponseDto` returns:
- `isCorrect`: boolean correctness flag.
- `pointsEarned`: exact points calculated by `CalculatePoints`.
- `coinsEarned`: coins derived from points ($\lceil \text{points} / 5 \rceil$).
- `comboStreak`: active streak count.
- `totalScore`: cumulative session score.

The datasource creates an `AnswerEvaluation`:
```dart
return AnswerEvaluation(
  isCorrect: resDto.isCorrect,
  pointsEarned: resDto.pointsEarned,
);
```
And [quiz_providers.dart](file:///Users/omkargeedh/Developer/Gamified%20Quiz%20App/Gamified-learning/lib/features/quiz/presentation/providers/quiz_providers.dart) appends a `QuestionAnswerRecord` to `QuizSessionViewState.records`.

---

## 4. Session Finalization & Maximum Score Alignment

When the last question is answered or Sudden Death ends:
1. `submitSession` calls `POST /quiz/sessions/complete`.
2. The response `SessionCompleteResponseDto` returns:
   - `finalScore`: total points earned via `CalculatePoints`.
   - `maxScore`: theoretical maximum points achievable under perfect speed ($1.5\times$) and streak ($2.0\times$).
   - `correctCount`: total questions answered correctly.
   - `totalQuestions`: total questions in the quiz.
   - `xpAwarded`, `coinsAwarded`, `gemsAwarded`: reward payouts.
   - `scoreBreakdown`, `coinBreakdown`, `xpBreakdown`: detailed line-item breakdown.
3. The resulting `QuizResult` constructs the immutable domain `Score`:
   ```dart
   final earnedPoints = resDto.finalScore > 0 ? resDto.finalScore : recordedPoints;
   final maxScore = resDto.maxScore > 0 ? resDto.maxScore : sessionMax;

   score: Score(
     earnedPoints: earnedPoints,
     maxPoints: maxScore,
     correctCount: resDto.correctCount,
     totalCount: resDto.totalQuestions,
   )
   ```

---

## 5. UI Presentation & Components

### 5.1 Score Panel ([quiz_result_view.dart](file:///Users/omkargeedh/Developer/Gamified%20Quiz%20App/Gamified-learning/lib/features/quiz/presentation/widgets/quiz_result_view.dart))
Displays the earned points relative to the total possible points:
```dart
Text(
  '${result.score.earnedPoints} / ${result.score.maxPoints}',
  style: context.appTextStyles.displayMedium,
)
```
- **Consistent Proportions**: 3 correct answers with multipliers will display e.g. **48 / 232** (or **82 / 280**), never **90 / 100** or clamped **125 / 125**.
- **100% Perfect Run**: Answering all questions correctly with top speed yields **232 / 232** or **280 / 280**.

### 5.2 Metrics & Accuracy
- **Correct Metric**: `${score.correctCount} correct` (e.g. `3 correct`).
- **Wrong Metric**: `${result.wrongCount} wrong` (e.g. `7 wrong`).
- **Accuracy Metric**: `${(result.accuracy * 100).round()}% accuracy` (e.g. `30% accuracy`).

### 5.3 Rewards & Economy
- **XP Pill**: `+${result.xpAwarded} XP`
- **Coins Pill**: `+${result.coinsAwarded} Coins`
- **Gems**: Up to 3 gems for high accuracy ($\ge 80\%$).
- **Level Up Banner**: Rendered if `result.didLevelUp == true`.

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
