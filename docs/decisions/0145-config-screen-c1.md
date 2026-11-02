# 0145 Config screen and Settings sheet (C1)

Status: Draft (owner review pending). Date: 2026-11-02. Partly replaces 0018 (the question source is now saved).

## Decision
Figma file J2jSbARJSyJCStNFeWkWDj, page "C1 Config screen" 337:2358 (screens 344:2971 to 344:5430,
sheet 349:4445 / 349:4681). Colours from `ElioTokens.light/dark` through the theme; fonts unchanged.

- Title "Connect ELIO" and the Settings button live in the N4 top bar (`ElioTopBar.trailing`), like Home.
- Robot hero keeps the real `Flutter3DViewer`, now drag-to-rotate (`enableTouch`). Status from
  `robotStatusProvider`: Online / Connecting / Offline / Not used (phone mode).
- **Battery shows "—"**: the robot does not send a battery value (no firmware or fake-robot field), so the
  hard-coded 62 % is gone. No parsing was added for a field nobody sends.
- ELIOS AI card: `GemmaStatus` idle → Off, installing/loading → Loading, ready → Active,
  error/killed/missing → Error (real message, Try again), paused → Paused (`blockedReason`).
  Activate = existing `prepare()` then `ensureReady(vision: true)` (scans need the image encoder).
  Only the one-time copy has a percent; the engine load shows an indeterminate bar.
- Logo = `LeafOrbitPainter`: outline is the Figma ellipse, small leaf moves at constant arc speed,
  outline gap follows it. Active 3.6 s per orbit, Loading 1.2 s, otherwise and with reduced motion still.
- Connection: one IP field + port (validated), connect logic moved from the widget into
  `configLinkProvider` so an attempt survives leaving the tab (no setState after dispose).
  A successful Connect still opens the Control screen (owner, 2 Nov); the Connected state shows
  while the link is up on Config (e.g. during the push), and leaving Control disconnects as before. Cancel really ends the attempt (`disconnect()` completes a cancel
  future in `WebSocketService.connect`). Failure shows the real reason; the timeout that fires is the
  service's 10 s (`WebSocketService.connectTimeout`), the old 12 s wrapper is only a guard. The
  failure snackbar shows only if the card is scrolled off screen.
- Auto-reconnect: a Config connect retries never; after success the setting applies to the live link
  (`setAutoReconnect`, also when toggled while connected).
- Quiz questions: `AppPreferences.questionSource` is now **saved** (owner request; 0018 had kept it
  in memory). Safe because the ELIOS AI tile needs a loaded model, the screen and quizzes use the bank
  until then, and a blocked Gemma already falls back to the bank with the reason as the first chat line.
  Release builds without `TESTER_BUILD` still always use the bank (`effectiveQuestionSource`).
- Settings sheet: Connection, Video, Sound, Quiz; the "Tampilan" section is gone (theme stays in the
  sidebar).

## Settings audit
| Setting | Saved | Effect |
|---|---|---|
| Auto-reconnect | yes (EspConfig) | already wired in Control; now also on Config links |
| Resolution | yes | already wired: sent to the robot on connect and on change |
| Show FPS overlay | yes | **newly wired**: hides the Control camera diagnostics badge when off (off by default) |
| Sound effects | yes (AppPreferences) | **UI only, not wired**: the app plays no sound effects |
| Master volume | yes | **newly wired** to quiz voice (TTS) volume, read at each quiz start |
| Difficulty | yes | already wired (question count/level) |
| Timer | yes | **UI only, not wired**: there is no per-question timer |
| Allow skipping | yes | already wired (skip button) |

## Consequences
- Bank tile says "Checked questions, instant" (the bank has 56 items, not Figma's "120").
- Tests: `test/screens/config_screen_test.dart` (28), `test/services/config_connection_test.dart` (10,
  local fake robot). Break-checked.
