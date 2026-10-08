# 0003: `stopGeneration` really stops LiteRT-LM, so no fallback

- Status: Accepted for cancels during decoding. Two observations from
  2026-10-09 (below, "Open for review") are for the owner to judge.
- Date: 2026-10-09
- Milestone: M0 (plan 1.1, items 2 and 3)
- Evidence: [`docs/test-results/m0-cancel.md`](../test-results/m0-cancel.md),
  test `integration_test/gemma_cancel_test.dart`

## Context

The plan asked whether `stopGeneration()` really stops LiteRT-LM, or only
stops the Dart side while the model keeps generating (case B). In case B the
fallback was: discard the output and keep the slot busy until the model
finishes.

## Decision

**Case A: it really stops.** The fallback is not implemented, and the slot
is released as soon as `cancel()` returns, as the code does today.

Measured on a real model (no mock), 3 runs of the final test version, 24
cancel trials in total (9 from the final version, 15 from the two earlier
versions):

| Measure | Median | Worst case |
|---|---|---|
| Cancel → native stream closed (model stopped generating) | 19 ms (final 9 trials) | **38 ms** (all 24 trials) |
| Cancel → next request starts generating | 21 ms (final 9 trials) | 46 ms (final 9 trials) |

The next request's first-token time (229–326 ms) is normal, so a stopped
generation leaves no hidden wait.

**Update, 2026-10-09 (retry batch).** Over all 57 M0.4 trials so far, the
stream closed 2–38 ms after the cancel. No cancel that landed mid-reply ever
failed to stop: across M0.3, M0.4 and M0.5b in the 5-run batch, every one
closed within 27 ms. Each cancel is confirmed on the native
side: the plugin logs `[LiteRtLmFfi] Generation cancelled`, and its decode
counter stops partway.

## Limits of this evidence

- **macOS only, Debug build** (Flutter 3.44.2, `flutter_gemma` 1.11.3,
  `flutter_gemma_litertlm` 1.8.5, GPU backend). Android, Release builds and
  other plugin versions are not measured. They belong to M5 (Android device
  test).
- **M0.3 infers the cancel point from timing, and retries misses.**
  `identifyItem` has no per-token callback, and adding one would change
  production code. So the test cancels 100 ms after the expected first
  token, taken from the most recent uncancelled warm identify. It then
  classifies the attempt from the service's own stream-closed log line.
  - A cancel that landed **before the first token**, **after the reply
    finished**, or when the reply **already had full length** is
    inconclusive and retried, up to 3 attempts per run. If all 3 are
    inconclusive, the run fails as inconclusive.
  - A cancel that landed **mid-reply** must close the stream within
    **150 ms**, or the test fails at once, with no retry. An identify reply
    that finishes on its own ends about 300 ms or more after the cancel
    point, so a cancel that did nothing cannot pass.
  - In 5 runs: 4 were conclusive (3 on the first attempt, 1 on the
    second), and 1 was inconclusive with all 3 attempts missing. The offset
    landed mid-reply in 4 of 8 attempts; the earlier 250 ms offset did in
    10 of 12 (see `m0-cancel.md`).
- **The M0.4 control check was relaxed to "non-empty generated text".** The
  control and the probe used to have to return a parsed question. Gemma
  sometimes writes 5 answer options, which the parser rejects, so the test
  failed on question content that has nothing to do with cancel (2 of 6
  runs of the earlier versions). The control now has to produce text that
  is **non-empty after trimming**, so whitespace-only text fails. The test
  takes that text from the parsed question (which `_parse` never accepts
  empty), or from the service's `unparseable question (attempt 1): <text>`
  log line, which holds the reply already trimmed by the service
  (`fullText.trim()`, `gemma_quiz_service.dart:367`). The probe still only
  has to stream (`chars > 0`, the untrimmed length from the `generated N
  chars` line), because its job is to show the engine served the next
  request. Every observed control was 564–734 characters. Whether the
  question parsed is still recorded in each trial's output.

## Open for review (observed 2026-10-09, no change made)

1. **A cancel during prefill takes effect only when prefill ends.** Prefill
   is the model reading the prompt; for identify, it includes encoding the
   photo.
   - Twice the cancel fired before the first token. The plugin reported
     `no chunks emitted`, and the stream closed **379 ms** and **6057 ms**
     after the cancel.
   - The service released the slot within 4 ms, but the plugin made the next
     request wait for the stopped one, so it started 376 ms and 6073 ms
     later.
   - So for this window, "the slot is free" and "the engine is free" are not
     the same thing. Requests don't overlap; the next one is only delayed.
   - The decision above holds for cancels during decoding. Whether a cancel
     during prefill needs handling, for example keeping the slot busy until
     the stream closes (the original fallback, for prefill only), is the
     owner's call.
2. **One native stall after a cancel.** In one of 5 runs, the request right
   after an M0.4 cancel decoded 48 chunks in about 15 minutes, instead of
   finishing in a few seconds.
   - The service's 120 s timeout and its `stopGeneration` call did not end it
     in time.
   - The Mac had rebooted about 28 minutes earlier and Spotlight was
     re-indexing at about 97% CPU. The same load did not cause a stall in the
     next run.
   - It is the first stall in 57 trials, and the cause is unknown. If it
     recurs on a quiet machine, it would weaken this decision. It matters for
     M5 (Android) and for the 120 s timeout path, which this stall shows
     cannot always stop the model.

## Consequences

- No production change for cancel in M0.
- Re-check on Android in M5, with the same test file.
- Re-run the test file on a quiet machine (no indexing) to see whether the
  stall recurs.
- If `flutter_gemma` or `flutter_gemma_litertlm` is upgraded, re-run
  `integration_test/gemma_cancel_test.dart` before trusting this record.
