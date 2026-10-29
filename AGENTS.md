# AGENTS.md — Gamified-learning (Flutter client)

SkillVerse Flutter app (Dart SDK ^3.11, Riverpod 2, GoRouter, `http`). Backend: `../GamifiedQuizApp_digitalHQ` on Zoho Catalyst.

## Commands

```bash
flutter pub get
flutter run                                   # pass --dart-define=BASE_URL=http://localhost:8080/api/v1 for local backend
flutter analyze
dart format <changed files>                   # don't format the whole repo; it rewrites unrelated files
flutter test                                  # or: flutter test test/<file>.dart
```

Baseline (2026-10-29): 17 tests already fail without a live backend (`backend_e2e_live_test`, `backend_integration_test`, `live_railway_sd_test`, a few UI flows). Compare failure lists before/after a change instead of expecting all green.

## Rules

- **When backend APIs change, update only the network/data layer** (`lib/core/network`, `features/*/data`, their tests). Do not change UI (screens/widgets). Provider edits are limited to dependency wiring and must be called out.
- Production URL default: `https://quiz-api-50046981183.development.catalystappsail.in/api/v1` (`lib/core/network/api_config.dart`). Railway is decommissioned — never use `*.up.railway.app`.
- Never push; the user reviews and pushes.

## Backend contract (keep in sync with the Go backend)

- Endpoints: `lib/core/network/api_endpoints.dart` (paths relative to `/api/v1`). Responses are `{success, message, data, errors}`; `ApiClient` returns `data` and throws `AuthException` (401/403), `NotFoundException` (404), `ValidationException` (400/409/422/429), `ServerException` — the exception `code` is the HTTP status, not the backend error code.
- Subjects: frontend topic ids map to backend subject codes in `lib/core/network/backend_topic_mapper.dart` (`accounting*` → `accounts`, `economics`, `maths` → `maths1`, `statistics`/`maths2` → `maths2`). `GET /subjects` (`ApiEndpoints.subjects`) lists subjects → chapters → per-mode question counts. `CreateSessionRequestDto.chapterNo` (`chapter_no`) limits a game to one chapter.
- Game modes: MCQ, Sort It Out, Match the Following, Sudden Death — all HTTP.
- MCQ is graded on the device: `QuizRemoteDatasource.evaluateAnswer` compares with the session's `correctOptionId` (no network) and queues the answer; `submitSession` sends all queued answers with `POST /quiz/sessions/complete` (`answers`), so a game costs one request after creation. The backend re-grades everything.
- Match the Following boards are dealt by the backend from a chapter's pairs; `question_code` of a board is a session-local `board-<n>`.
- **Sudden Death has no WebSocket.** Catalyst does not tunnel WebSockets, so `RestSuddenDeathClient` (`features/quiz/data/datasources/remote/sudden_death_rest_client.dart`) implements the `SuddenDeathSocketClient` interface over `POST /quiz/sudden-death/{question,answer,power-up}`. It emits the same `WsServerEvent`s the controller already handles, posts `timeout` when the server's `remaining_time_ms` runs out, adds the 400 ms result→question transition, and maps transport failures to `socket_error` (controller reconnect/resync) and game over to `socket_closed_normal`. The `Ws*` DTO names are historical.

## Tests

- Widget/integration tests override datasources with mocks and `localStorageServiceProvider`; see `test/widget_test.dart` and `test/sudden_death_remote_datasource_test.dart` (`MockClient` + `ApiClient`).
- UI tests scroll and pump timed animations; set `tester.view.physicalSize`/`devicePixelRatio` for layout-sensitive tests (e.g. Sort It Out).
