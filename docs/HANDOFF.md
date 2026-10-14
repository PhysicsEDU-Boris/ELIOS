# Handoff

- Branch: `fix/m2b-tts-cancel-clock`
- Latest commit: `f07b64e`
- PR: [#15](https://github.com/PhysicsEDU-Boris/ELIOS/pull/15) into `feature/live-scan` — open, not merged
- **Working tree has uncommitted changes**, not yet pushed to PR #15.

## Done (in commit f07b64e)

- TTS de-dup (no repeat reply per quiz) + `tts N` in the debug overlay.
- `cancel()`/`stopGeneration()` awaited instead of fire-and-forget (first pass).
- Overlay no longer shows a stale `first token`/`question` time from a prior quiz.
- Stabilizer/state machine/controller default to a shared `monotonicClock()`.
- Per-question debug log line (label, index/total, type, load time, first token, fallback).
- Decision 0010 added; decision 0003 updated for the first-pass `cancel()` change.

## In progress — uncommitted

PR #15 review: `cancel()`/the yield-to-user path must release the cancelled
caller **before** awaiting `_stopGeneration()` (a prefill-time cancel can take up
to 6 s to land, decision 0003), and `_stopGeneration()` needs a 2 s cap.

- Applied in `lib/services/gemma_quiz_service.dart`: `_stopInFlight` (blocks a new
  generation while the old stop settles), 2 s cap, reordered `cancel()`/`_send`.
- Found and fixed a real race: completing the active completer schedules the
  pending-task promotion as a microtask; `_pendingTask` must be set *before* that
  completion, not after — fixed in `_send`.
- Added `fake_async` dev_dependency + a new test (`test/quiz_behavior_test.dart`)
  per the review's exact scenario.

### Next step (exact)

1. `flutter test` (full suite) — only `quiz_behavior_test.dart` checked so far (16/16, no hang).
2. Break-check the new fakeAsync test (old order should fail it); restore the fix.
3. Update decision 0003's section with the reorder + 2 s cap + `_stopInFlight`.
4. Commit the 4 changed files, `scripts/check-secrets.sh`, push, update PR #15. Do not merge.

## Tests

- `flutter analyze`: clean.
- `quiz_behavior_test.dart`: 16/16 passed.
- Full suite not re-run since the fix; last full run (f07b64e) was 183 passed, 2
  known-failing (`test/widget_test.dart` splash tests, pre-existing).

## Decisions

- [0003](decisions/0003-stop-generation.md) — cancel() awaits stopGeneration; needs the reorder update still written in.
- [0010](decisions/0010-tts-single-slot-and-overlay-staleness.md) — TTS, clock, staleness, timing log.

## Robot test needed

Nothing in PR #15 tried on the robot yet. See the PR's "How to test on the robot"
section. Once the cancel reorder is committed: switch objects mid-quiz (the
yield-to-user path) and confirm the UI doesn't stall waiting on the native stop.
