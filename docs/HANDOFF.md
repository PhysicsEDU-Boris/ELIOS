# Handoff

- Branch: `feat/quiz-prefetch`
- Latest commit: see `git log -1`
- PR: #16 into `feature/live-scan`

## Done (this task)

- M2b part 3 (background quiz prefetch): questions 2-N of a session are now
  generated through the single Gemma slot in the background, one at a time,
  starting the instant question 1 shows. "Soal berikutnya" shows instantly
  when the buffer already has the question, or "Menyiapkan soal
  berikutnya…" while it's still generating.
- `GemmaQuizService`: extracted `_tryGenerateQuestion` (shared by
  `generateQuestion` and the new `generateQuestionBackground`), added a
  `'CANCELLED'` sentinel (alongside the existing `'BUSY'`) so a background
  caller can tell "pre-empted by a higher-priority request — retry" apart
  from a real failure; added near-duplicate rejection against the existing
  avoid-list.
- `WasteQuizNotifier`: `_startPrefetch`/`_runPrefetch`/`_generateForBuffer`/
  `_cancelPrefetch`/`_consumeQuestion`. A chat message or essay grading
  (decision 0003) pauses prefetch and it resumes after — never falls back
  because of a chat message. Closing the quiz or starting a new session
  cancels prefetch and clears the buffer.
- Debug overlay/log: `_consumeQuestion` logs the wait per "Soal berikutnya"
  tap (0 from the buffer); overlay adds `next N ms`
  (`LiveScanController.nextWaitMs`, wired in `control_screen.dart`).
- Decision doc [0011](decisions/0011-quiz-prefetch.md); `CHANGELOG.md`
  updated.

## Tests

- `flutter analyze`: clean.
- `flutter test test/quiz_behavior_test.dart`: 23/23 passed (new group:
  "M2b part 3: background quiz prefetch").
- `flutter test` (full suite): 189 passed, 2 known-stale
  (`test/widget_test.dart` splash tests, pre-existing).
- `scripts/check-secrets.sh`: clean.
- Break-checked 3 of the new tests against the pre-fix code, each failed,
  then restored and re-verified green:
  - "instant from buffer" — reverted `_advance()` to call `_loadQuestion`
    again instead of consuming the buffer.
  - "close cancels" — removed the `_cancelPrefetch()` call from `dismiss()`.
  - "chat doesn't cause fallback" — made a cancelled background attempt
    report `retry: false` (the old behaviour).

## Robot test needed

Nothing in PR #16 tried on the robot yet. Build:
`flutter build macos --debug --dart-define=LIVE_SCAN=true`, launch with
`open` (not `flutter run`, breaks Local Network permission). Run a
medium/hard-difficulty session, chat with the assistant *before* tapping
"Soal berikutnya" a few times, and confirm:
- questions 2+ appear with no visible wait when the buffer had time to fill;
- a question is never shown as "SOAL CADANGAN" just because you were
  chatting when it was due;
- the overlay's `next N ms` reads near-0 when prefetched, and a real number
  (not "-") on the rare case it had to wait;
- closing the quiz mid-session and starting a new scan doesn't leak a
  question from the old object into the new one.

## Decisions

- [0003](decisions/0003-stop-generation.md) — stopGeneration; single-slot
  busy/cancel rules this task's background prefetch builds on.
- [0009](decisions/0009-camera-stays-alive.md) — camera stays alive during a
  quiz; Gemma preloads.
- [0010](decisions/0010-tts-single-slot-and-overlay-staleness.md) — TTS,
  clock, staleness, timing log this task's "waited ms" log line matches.
- [0011](decisions/0011-quiz-prefetch.md) — this task.
