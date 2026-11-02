# Host character system

A reusable animated host (`assets/character/character.png`) that reacts to play.
Code lives in `lib/features/character/`. Only **MCQ** is wired today.

```
game state ──► adapter ──► CharacterEvent ──► CharacterController ──► CharacterView
(per mode)    (only game-aware file)          (state machine)         (pure drawing)
                                                   └─► speech stream ─► CharacterSpeechBubble
```

| File | Role |
| --- | --- |
| `domain/character_state.dart` | `CharacterState` enum, priority, one-shot/terminal flags |
| `domain/character_event.dart` | `CharacterEvent` inputs |
| `domain/character_strings.dart` | All speech lines (no l10n system exists yet; replace this one map when it does) |
| `application/character_controller.dart` | State machine + speech. No widgets, sockets, scoring or questions |
| `presentation/character_pose.dart` | Pure `state + t → transform` maths (translate/scale/rotate/glow) |
| `presentation/character_view.dart` | Draws the pose. Props: `controller`, `size` (height) |
| `presentation/character_speech_bubble.dart` | One short line, auto-hides |
| `presentation/character_assets.dart` | Asset paths, preload, layer detection |
| `presentation/character_providers.dart` | `characterControllerProvider` (auto-disposed per session) |
| `presentation/mcq_character_adapter.dart` | MCQ → events (about 30 lines) |

## States

Priority decides what is shown when things overlap: `result* > timeout > hurry > thinking > intro > presenting > idle`
(`streak` outranks `correct/wrong`; `win/lose` are terminal).

| State | Priority | Kind | Look |
| --- | --- | --- | --- |
| `idle` | 0 | loop | breathing (scaleY 1→1.015), tiny bob |
| `presenting` | 1 | settles after 1 s | lean toward question, small tada |
| `intro` | 2 | one-shot 1.6 s | slide in with overshoot, hand-gesture tilt |
| `thinking` | 3 | loop | slow sway, ~3° head tilt, blinks (layers only) |
| `hurry` | 4 | loop | faster bob + shake, scales with `intensity` |
| `timeout` | 5 | one-shot 1.6 s | shrug-like sink (+8 px equiv.), slow recover |
| `correct` | 6 | one-shot 1.4 s | pop 1→1.08→1, cyan glow, bounce |
| `wrong` | 6 | one-shot 1.4 s | quick shrink, ±3° head shake, dim glow |
| `streak` | 7 | one-shot, longer with level | bigger celebration, orange glow (level 1/2/3 for 3/5/10+) |
| `win` | 8 | terminal loop | long celebration |
| `lose` | 8 | terminal loop | calm, encouraging sway |

One-shots hand back to a baseline (`idle`, or `thinking` while a timer runs) on their own. A lower-priority
one-shot never interrupts a higher one. `win/lose` stay until `reset()`.

## Events

| Event | Effect |
| --- | --- |
| `gameStarted` | `reset()` then `intro` + speech |
| `questionShown` | baseline `presenting`, settles to `idle`/`thinking` after 1 s |
| `timerTick(f)` | `f` = remaining fraction. ≤ 0.25 → `hurry` (intensity grows as `f`→0), else `thinking` |
| `answerSubmitted` | stops the timer phase, baseline `thinking` |
| `resultCorrect` / `resultWrong` | one-shot reaction + speech |
| `timeExpired` | `timeout` one-shot |
| `streakReached(n)` | `n ≥ 3` → `streak` one-shot |
| `gameEnded(won)` | terminal `win` / `lose` |

Also: `controller.reset()` (screen exit, reconnect) and `controller.dispose()` cancel every timer.

## Plugging in a new mode

1. Write an adapter like `mcq_character_adapter.dart`: take the controller, expose a few methods that call
   `controller.send(CharacterEvent...)`. Keep it free of animation code.
2. Call it from your screen **after the frame** (e.g. `addPostFrameCallback`) so listeners are never notified mid-build.
3. Watch `characterControllerProvider` in the screen (keeps it alive for the session; auto-disposed afterwards).
4. Place `CharacterView(controller:, size:)` and optionally `CharacterSpeechBubble(controller:)` in a reserved slot.

## MCQ specifics

MCQ is graded after the last question and has no timer, and the character is deliberately **not** given
question, option or correctness data. It only gets `gameStarted`, `questionShown`, `answerSubmitted`,
`gameEnded(won: true)` (meaning "quiz finished", not a score verdict). Correct/wrong/streak/timer states exist
for modes that receive a real per-answer result (see proposals in the change summary).

## Layered assets (optional)

Drop these into `assets/character/layers/` (same canvas size and origin as `character.png`, so they stack at 0,0):
`body.png`, `arm_right.png`, `head.png`, `eyes_open.png`, `eyes_closed.png`, `mouth_closed.png`, `mouth_open.png`.
Then add `- assets/character/layers/` to `pubspec.yaml`. `CharacterAssets.layersAvailable()` detects the full set
and the view switches to layers automatically: random blinks (3–6 s, while `thinking`) and a ~8 Hz talking mouth
while a line is shown. No API change. If any layer is missing it silently keeps using the whole image.

## Performance and safety notes

- Only transforms/opacity; the character is wrapped in a `RepaintBoundary`.
- Loop animations are bounded (24 passes, ~45 s; `win` 120) and restart on state change; the ticker stops when
  the app is backgrounded and when the OS reduce-motion setting is on (static pose, steady glow only).
- The image is decoded at the display size (`cacheHeight`). Only one 765×1024 file ships; add `2.0x/3.0x` variants if memory matters.
- If the art fails to load the view shows an empty box; gameplay is unaffected.
