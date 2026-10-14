# 0003: `stopGeneration` really stops LiteRT-LM, so no fallback

- Status: Accepted. A cancel during prefill only takes effect when prefill
  ends; that is kept as a known limit (below).
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

**Update, 2026-10-09.** Over all 72 M0.4 trials, the stream closed **2–38 ms**
after the cancel (median 14 ms). No cancel that landed mid-reply ever failed
to stop, in M0.3, M0.4 or M0.5b. In the last 5-run batch (Mac kept awake),
every test passed in every run. Each cancel is confirmed on the native
side: the plugin logs `[LiteRtLmFfi] Generation cancelled`, and its decode
counter stops partway.

## Limits of this evidence

- **macOS only, Debug build** (Flutter 3.44.2, `flutter_gemma` 1.11.3,
  `flutter_gemma_litertlm` 1.8.5, GPU backend). Android, Release builds and
  other plugin versions are not measured. They belong to M5 (Android device
  test).
- **M0.3 infers the cancel point from timing, and retries misses.**
  `identifyItem` has no per-token callback, and adding one would change
  production code. So the test cancels **250 ms** after the expected first
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
  - Final batch (250 ms, Mac kept awake with `caffeinate -dimsu`): 5 of 5
    runs conclusive on the first attempt, with no retry needed. Over all
    batches the 250 ms offset landed mid-reply in 15 of 17 attempts. A
    100 ms offset was tried and landed mid-reply in only 4 of 8, so it was
    dropped.
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

## Known limit: a cancel during prefill takes effect when prefill ends

Prefill is the model reading the prompt; for identify, it includes encoding
the photo.

- Twice a cancel fired before the first token. The plugin reported
  `no chunks emitted`, and the stream closed **379 ms** and **6057 ms**
  after the cancel. The 6 s case happened during a slow period, when the
  next identify's prefill took 13.5 s.
- The service releases the slot at once (within 4 ms). The plugin then makes
  the next request wait for the stopped one, so it started 376 ms and
  6073 ms later.
- Requests never overlap. The next one is only delayed, at most until the
  stopped prefill ends.
- Accepted as a known limit: no change. If that delay ever matters for the
  user (for example, a user request right after a scan is dismissed during
  identify), the option is to keep the slot busy until the stream closes,
  for prefill cancels only.

## Test environment note: the 15-minute "stall" was the Mac sleeping

In one run, the request right after a (successful) cancel took about
15 minutes (`decode 900407ms over 48 chunks`).

- The macOS power log shows the Mac in idle sleep for **899 s, from 01:34:35
  to 01:49:34 WIB**, inside that run (01:31:44–01:49:39). The run exited
  5 s after the wake.
- So it was the test environment, not the plugin or the cancel.
- Later runs use `caffeinate -dimsu`, and the following 5 runs had no stall
  and no sleep or wake events.
- The raw numbers are kept in `m0-cancel.md`.

## Update, 2026-10-14 (M2b part 2): `cancel()` now awaits `stopGeneration()`

`stopGeneration()` returns a `Future<void>`. The 3 call sites in
`gemma_quiz_service.dart` (`cancel()`, the timeout handler, and `_send`'s
"user request cancels a scan" branch) used to fire it without awaiting:
`try { _chat?.stopGeneration(); } catch (_) {}`. That `try/catch` only
catches a *synchronous* throw; an async rejection from the native call
could escape as an unhandled `Future` error. All 3 now go through one
`Future<void> _stopGeneration()` helper that awaits it and logs (not
throws) on failure. `cancel()` itself changed from `void` to
`Future<void> cancel() async`; none of its 4 call sites (all in
`waste_quiz_provider.dart`) needed to change, since none awaited it before
either.

**Behaviour change, within the measured range above:** the slot now
releases after `stopGeneration()` settles (2–38 ms, median 14–19 ms per
this record) instead of firing it and releasing immediately. Decision 0003
already established that range as small; this doesn't invalidate the
timing evidence above, which measured the native stop itself, not when the
Dart-side slot was released.

**Single-slot rules unchanged:** BUSY (a non-user request is rejected
outright while a request is active) and a user request cancelling an
active scan both still work exactly as before — only the cancel mechanics
changed, not when a cancel happens.

**Cut-off reply in chat history: left as is, by design, not a bug.**
`InferenceChat` (the `flutter_gemma` package) already drops a cancelled
*empty* response from history (its own fix for issue #325) but keeps a
*non-empty* one that was cut off mid-stream — plausible on the ~88% of
cancels that land mid-reply (per the table above). Checked whether this
can leak into the app: every real caller in `gemma_quiz_service.dart`
(`identifyItem`, `generateQuestion`, `discuss`, `reviewEssay`) calls
`_send(..., fresh: true, ...)`, which clears history (`clearHistory()`)
*before* adding its own prompt — so a cut-off reply is always wiped before
anything could read it. `fullHistory` (the package's only read API for it)
is never read anywhere in this app. The package's own way to selectively
drop one message (`clearHistory(replayHistory: ...)`) closes the session
and replays every remaining turn through the model — real cost, for a
state that's already provably unreachable here. No code change.

Tests: `test/quiz_behavior_test.dart`, group "GemmaQuizService single
flight slot logic" — `cancel()` awaits a mocked `stopGeneration` and a
throwing one doesn't escape (`mockStopGeneration`, a new
`@visibleForTesting` seam alongside the existing `mockSendExecute`).

## Consequences

- No production change for cancel in M0.
- Re-check on Android in M5, with the same test file.
- Run the real-model tests under `caffeinate -dimsu`, with no media
  playing, so sleep and GPU contention don't distort the timings.
- If `flutter_gemma` or `flutter_gemma_litertlm` is upgraded, re-run
  `integration_test/gemma_cancel_test.dart` before trusting this record.
- M2b part 2 (2026-10-14): `cancel()` awaits `stopGeneration()`; see the
  update above. Re-run the cancel integration test if this changes the
  measured stop/next-request timing meaningfully.
