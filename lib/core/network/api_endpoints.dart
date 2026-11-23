/// Central definition of all backend REST and WebSocket routes.
/// Routes correspond exactly to the Go Gin backend endpoints in GamifiedQuizApp_digitalHQ.
class ApiEndpoints {
  ApiEndpoints._();

  // Health
  static const String health = '/health';

  // Core Authentication & Session
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String signupSendCode = '/auth/signup/send-code';
  static const String signupResendCode = '/auth/signup/resend-code';
  static const String signupVerify = '/auth/signup/verify';
  static const String forgotPassword = '/auth/forgot-password';
  static const String forgotPasswordVerify = '/auth/forgot-password/verify';
  static const String forgotPasswordReset = '/auth/forgot-password/reset';
  static const String session = '/session';
  static const String verifySession = '/verify-session';
  static const String changePasswordRequest = '/change-password-request';
  static const String changePasswordVerify = '/change-password-verify';

  // Profile & Onboarding
  static const String profile = '/profile';
  static const String profileSetup = '/profile/setup';
  static const String profileOptions = '/profile/options';
  static const String profileSetupOptions = '/profile/setup-options';

  // Quiz, Topics & Gameplay
  static String topicQuestions(String topicId) => '/topics/$topicId/questions';
  static const String subjects = '/subjects';
  static const String quizCreateSession = '/quiz/sessions/create';
  static const String quizEvaluateAnswer = '/quiz/answers/evaluate';
  static const String quizFiftyFifty = '/quiz/power-ups/fifty-fifty';
  static const String quizCompleteSession = '/quiz/sessions/complete';
  static const String quizSortItOutComplete = '/quiz/sort-it-out/complete';
  static const String quizMatchTheFollowingComplete =
      '/quiz/match-the-following/complete';
  static const String quizAbandonSession = '/quiz/sessions/abandon';
  static const String suddenDeathQuestion = '/quiz/sudden-death/question';
  static const String suddenDeathAnswer = '/quiz/sudden-death/answer';
  static const String suddenDeathPowerUp = '/quiz/sudden-death/power-up';
  static const String quizHistory = '/quiz/history';
  static const String gameWs = '/ws/game';

  // Wallet
  static const String walletBalance = '/wallet/balance';
  static const String walletCredit = '/wallet/credit';
  static const String walletDebit = '/wallet/debit';
  static const String walletTransactions = '/wallet/transactions';

  // Google Play Billing (verified on the server; the app never grants anything)
  static const String billingProducts = '/billing/products';
  static const String billingAccountId = '/billing/account-id';
  static const String billingVerify = '/billing/verify';
  static const String billingEntitlements = '/billing/entitlements';
  static const String passMonthlyGems = '/pass/monthly-gems';

  // Rewarded ads (paid only after Google's signed server-side callback)
  static const String adsConfig = '/ads/config';
  static const String adsRewards = '/ads/rewards';
  static String adsReward(String id) => '/ads/rewards/$id';
  static String adsRewardDevComplete(String id) =>
      '/ads/rewards/$id/dev-complete';

  // Power-ups charged on the server (prices and token balances)
  static const String powerUps = '/power-ups';

  // Spin wheel
  static const String spinWheelSegments = '/spin-wheel/segments';
  static const String spinWheelStatus = '/spin-wheel/status';
  static const String spinWheelSpin = '/spin-wheel/spin';

  // Daily goals
  static const String dailyGoals = '/daily-goals';
  static const String dailyGoalsClaim = '/daily-goals/claim';

  // Streak rewards
  static const String streak = '/streak';
  static const String streakClaim = '/streak/claim';
  static const String streakFreeze = '/streak/freeze';

  // Usage analytics
  static const String analyticsEvents = '/analytics/events';

  // Leaderboard
  static const String leaderboard = '/leaderboard';
}
