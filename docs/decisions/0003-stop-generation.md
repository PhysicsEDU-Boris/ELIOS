# 0003: `stopGeneration` really stops LiteRT-LM, so no fallback

- Status: Accepted
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
generation leaves no hidden wait. Each cancel is confirmed on the native
side: the plugin logs `[LiteRtLmFfi] Generation cancelled`, and its decode
counter stops partway.

## Limits of this evidence

- **macOS only, Debug build** (Flutter 3.44.2, `flutter_gemma` 1.11.3,
  `flutter_gemma_litertlm` 1.8.5, GPU backend). Android, Release builds and
  other plugin versions are not measured. They belong to M5 (Android device
  test).
- **M0.3 infers the cancel point from timing.** `identifyItem` has no
  per-token callback, and adding one would change production code. So the
  test cancels at a warm identify's first-token time + 250 ms. It then
  checks, from the service's own stream-closed log line, that the first
  token came before the cancel and that the stream was still open when the
  cancel fired. If either check fails, the test fails as "inconclusive"
  instead of passing. The stream must close within **150 ms** of the cancel.
  An identify reply that finishes on its own ends about 300 ms after this
  cancel point, so with the earlier 1000 ms limit, a cancel that did
  nothing would have passed (see `m0-cancel.md`).
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

## Consequences

- No production change for cancel in M0.
- Re-check on Android in M5, with the same test file.
- If `flutter_gemma` or `flutter_gemma_litertlm` is upgraded, re-run
  `integration_test/gemma_cancel_test.dart` before trusting this record.
