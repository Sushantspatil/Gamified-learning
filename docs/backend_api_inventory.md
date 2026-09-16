# Backend API Inventory

Backend reviewed: `OmkarGeedh/GamifiedQuizApp_digitalHQ` at commit `407c515`.

The backend wraps successful responses as `{ "success": true, "message": "...", "data": ... }` and errors as `{ "success": false, "message": "..." }`. Protected routes accept `Authorization: Bearer <accessToken>`. The Flutter `ApiClient` already unwraps `data` and attaches the stored token.

## Deployment

- The repository contains a production Dockerfile and a commit labelled for Railway deployment.
- No public deployment URL is committed in the repository, set as the GitHub repository homepage, or exposed through GitHub Deployments.
- Until the backend owner supplies or creates a public HTTPS domain, the Android release build cannot use a production `BASE_URL`.

## Authentication

| Frontend flow | Current production source | Backend endpoint | Request / response | Auth | Status |
| --- | --- | --- | --- | --- | --- |
| Login | `AuthRemoteDatasource` | `POST /api/v1/auth/login` | `{email,password}` -> access token, refresh token, client | No | Integrated |
| Sign up | `AuthRemoteDatasource` | `POST /api/v1/auth/register/validate-basic` | `{username,email,password}` | No | Integrated; backend also exposes email/phone verification flows |
| Restore session | `AuthRemoteDatasource` | `GET /api/v1/session` | client session | Bearer | Integrated |
| Refresh token | Central `ApiClient` retry | `POST /api/v1/auth/refresh` | `{refreshToken}` -> access token | No | Integrated |
| Logout | Remote call followed by local cleanup | `POST /api/v1/auth/logout` | logout confirmation | Bearer | Integrated |
| Update display name | `AuthRemoteDatasource` | `PUT /api/v1/profile` with `{name}` | updated profile | Bearer | Integrated |
| Forgot/change password | No complete frontend integration | Several `/api/v1/auth/forgot-password*` and `/api/v1/change-password-*` routes | See backend DTOs | Mixed | Backend available; frontend integration missing |

Demo seed login: `player@example.com` / `secretpassword123`.

## Profile, Dashboard, Wallet, And Streak

| Frontend feature | Current dummy source | Backend endpoint | Request / response | Auth | Status |
| --- | --- | --- | --- | --- | --- |
| Profile read | `ProfileRemoteDatasource` | `GET /api/v1/profile` | name, avatar, XP, level, coins, gems, streak, weekly score/rank | Bearer | Integrated in local frontend/backend changes |
| Profile create/update | `ProfileRemoteDatasource` | `POST /api/v1/profile`, `PUT /api/v1/profile` | profile fields | Bearer | Update integrated; create endpoint remains available |
| Class, board, selected subjects, setup/tutorial flags | `ProfileRemoteDatasource` | `PUT /api/v1/profile` | persisted profile setup fields | Bearer | Added to local backend schema/DTO changes |
| Dashboard XP/level/avatar | Remote profile provider | `GET /api/v1/profile` | profile values | Bearer | Integrated |
| Wallet balance | `WalletRemoteDatasource` | `GET /api/v1/profile` | coins and gems | Bearer | Integrated read-only |
| Wallet credit/debit/history | `WalletMockDatasource` | None | Backend has a ledger table but no wallet routes | N/A | Backend gap |
| Streak read/app-open | `StreakRemoteDatasource` | `GET /api/v1/profile` | current/highest streak and seven-day history | Bearer | Integrated read; no explicit app-open endpoint |
| Weekly rank | Mock leaderboard/profile values | `GET /profile` | current user's weekly rank only | Bearer | Partial backend support |

## Questions And Quiz

| Frontend flow | Current dummy source | Backend endpoint | Request / response | Auth | Status |
| --- | --- | --- | --- | --- | --- |
| Fetch MCQ questions | `QuestionRemoteDatasource` | `GET /api/v1/topics/:topic_id/questions?limit=10` | topic, total, time limit, MCQ questions | Bearer | Integrated without production fallback; seed currently only `accounting` |
| Create MCQ session | `QuizRemoteDatasource` | `POST /api/v1/quiz/sessions/create` | `{topic,question_count,abandon_stale}` -> session/questions | Bearer | Integrated without production fallback |
| Evaluate MCQ answer | `QuizRemoteDatasource` | `POST /api/v1/quiz/answers/evaluate` | `{session,question,option,time_taken_ms}` -> correctness and score | Bearer | Integrated; server result is authoritative |
| Complete MCQ session/result | `QuizRemoteDatasource` | `POST /api/v1/quiz/sessions/complete` | `{session}` -> authoritative score, XP, coins, gems, level, streak | Bearer | Integrated; local duplicate rewards removed |
| Abandon session | Not called | `POST /api/v1/quiz/sessions/abandon` | `{session}` | Bearer | Backend available; frontend integration missing |
| 50:50 | Remote call when a server session exists | `POST /api/v1/quiz/power-ups/fifty-fifty` | `{session,question}` -> hidden options | Bearer | Integrated; no server-side wallet charge |
| Quiz history | No production integration | `GET /api/v1/quiz/history?limit=&offset=` | paginated sessions | Bearer | Backend available; frontend integration missing |
| Match the Following | `QuestionMockDatasource` / `QuizMockDatasource` | None | No matching DTO or route | N/A | Backend gap |
| Sort It Out | `QuestionMockDatasource` / `QuizMockDatasource` | None | No sorting DTO or route | N/A | Backend gap |
| Sudden Death | MCQs converted into sudden-death questions | None | No separate mode/session contract | N/A | Backend gap; conversion must not be treated as real API support |

## Content And Economy Features

| Frontend feature | Current production source | Backend endpoint | Status |
| --- | --- | --- | --- |
| Learning paths / subjects | `LearningPathMockDatasource` | None | Backend gap |
| Chapters and topics | `ChapterMockDatasource` | None | Backend gap |
| Learning material | Static/mock frontend data | None | Backend gap |
| Leaderboard | `LeaderboardMockDatasource` | None | Backend gap |
| Shop and purchases | `ShopMockDatasource` plus local wallet debit | None | Backend gap |
| Cosmetics inventory/equip | `CosmeticsMockDatasource` | None | Backend gap |
| Daily rewards | `DailyRewardMockDatasource` plus local wallet credit | None | Backend gap |
| Daily missions | `DailyMissionMockDatasource` plus local wallet credit | None | Backend gap |
| Chests | `ChestMockDatasource` plus local wallet credit | None | Backend gap |
| Spin wheel | `SpinWheelMockDatasource` plus local wallet credit | None | Backend gap |

## Integration Boundary

Production code now uses the real backend for authentication, profile, wallet balance, streak reads, and MCQ sessions. The corresponding backend profile changes must be committed and deployed before publishing an APK that uses them. All other listed features require backend contracts before their production mocks can be removed without breaking the existing screens.
