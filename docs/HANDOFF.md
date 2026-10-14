# Handoff

- Branch: `fix/m2b-tts-cancel-clock`
- Latest commit: see `git log -1`
- PR: [#15](https://github.com/PhysicsEDU-Boris/ELIOS/pull/15) into `feature/live-scan` — open, not merged

## Done (this task)

- Added repo-root `CLAUDE.md` (permanent working rules), committed separately.
- PR #15 review fix landed and pushed: in `GemmaQuizService`, `cancel()` and
  `_send`'s "user request cancels an active scan" path now release the
  cancelled caller **before** awaiting `_stopGeneration()` (a prefill-time
  cancel can otherwise take up to 6 s to land, decision 0003).
  `_stopGeneration()` is capped at 2 s (`.timeout`, logs not throws).
  `_stopInFlight` keeps a new generation from starting on the same chat
  session while the old stop is still settling, without holding up the
  cancelled caller.
- Decision 0003 updated with a "Fix, 2026-10-14 (PR #15 review)" section.
- `CHANGELOG.md` updated (Fixed entry).
- `test/quiz_behavior_test.dart`: new `fakeAsync` test for this exact
  scenario (mocked 5 s native stop; asserts the caller is freed within
  50 ms and `cancel()` itself settles at the 2 s cap).

## Tests

- `flutter analyze`: clean.
- `flutter test test/quiz_behavior_test.dart`: 16/16 passed.
- Break-check: reverted the reorder in `cancel()` only — the new
  `fakeAsync` test failed ("the active caller must not be held up by the
  5 s stop"); fix restored and re-verified (16/16 again).
- `flutter test` (full suite): 182 passed, 2 known-stale
  (`test/widget_test.dart` splash tests, pre-existing).
- `scripts/check-secrets.sh`: clean.

## Decisions

- [0003](decisions/0003-stop-generation.md) — stopGeneration; reorder + 2 s
  cap + `_stopInFlight` fix now written in.
- [0010](decisions/0010-tts-single-slot-and-overlay-staleness.md) — TTS, clock, staleness, timing log.

## Robot test needed

Nothing in PR #15 tried on the robot yet. Build:
`flutter build macos --debug --dart-define=LIVE_SCAN=true`, launch with
`open` (not `flutter run`, breaks Local Network permission). Switch
objects mid-quiz (the yield-to-user path) and confirm the UI doesn't stall
waiting on the native stop.
