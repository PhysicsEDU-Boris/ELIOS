# M0.3/M0.4: real cancel test and whether `stopGeneration` stops LiteRT-LM

- **Date:** 2026-10-09 (runs 00:09–00:15 WIB)
- **Device:** macOS 27.0 (26A428), arm64, Flutter 3.44.2
- **Model:** `gemma-4-E2B-it.litertlm` on `PreferredBackend.gpu`
- **Plugins:** `flutter_gemma` 1.11.3, `flutter_gemma_litertlm` 1.8.5 (FFI engine)
- **Build mode:** Debug (`flutter test integration_test/gemma_cancel_test.dart -d macos`)
- **Test:** `integration_test/gemma_cancel_test.dart`, real model, no mock, no
  production code changed. Run 3 times in a row, nothing else running.
- **Result:** 3 of 3 runs, both tests passed.

## Verdict for M0.4: case A, `stopGeneration` really stops generation

The fallback ("discard the output and keep the slot busy until the model
finishes") is **not needed**.

Evidence, in order, for every cancel:

1. `GemmaQuizService.cancel()` logs `canceling active request` and calls
   `_chat.stopGeneration()`.
2. The plugin calls native `cancelGeneration()`
   (`flutter_gemma_litertlm` `ffi_inference_model.dart`), and native logs
   `[LiteRtLmFfi] Generation cancelled`.
3. Native reports `CANCELLED`, the plugin closes the stream
   (`litert_lm_client.dart`), and the plugin's own counter shows decoding
   stopped part way, for example `generation total: 1514ms (prefill 245ms +
   decode 1269ms over 54 chunks)` for a reply that normally runs 3.4–4.8 s.
4. The stream's `onDone` fires, and the service logs `generated N chars`
   with N well below a full reply.

## How it's measured

The service already prints `[GemmaQuizService] generated N chars (first
token: Xms, total: Yms)` from the response stream's `onDone`, and still
prints it after a cancel. The test timestamps that line, so it gives the
moment the native stream closed, how many characters came out, and when the
first token arrived. Nothing is added to production code.

`identifyItem` has no per-token callback, and adding one would be a
production change. So M0.3 times the cancel from a warm, uncancelled
identify in the same run (its first-token time + 250 ms). It then checks
afterwards that the first token arrived before the cancel and that the
stream was still open when the cancel fired. If either check fails, the test
fails as "inconclusive" instead of passing.

## M0.3: cancel identify after the first token

Check: tokens stop, the slot is free, and the next identify returns the right
item.

| Run | Full identify (control) | Cancel fired | Chars when cancelled | Stream closed after cancel | Caller released after cancel | Next identify | Next started after release |
|---|---|---|---|---|---|---|---|
| 1 | 79 chars, first token 3258 ms | 249 ms after first token | 35 / 79 | 6 ms | 1 ms | ponsel pintar | 6 ms |
| 2 | 79 chars, first token 3113 ms | 274 ms after first token | 38 / 79 | 25 ms | 1 ms | ponsel | 24 ms |
| 3 | 79 chars, first token 3076 ms | 112 ms after first token | 16 / 79 | 7 ms | 1 ms | ponsel pintar | 8 ms |

- **Tokens stop:** each cancelled stream closed 6–25 ms after cancel, with
  16–38 of 79 characters. The test now fails if the stream is still open
  **150 ms** after cancel (it was 1000 ms, see below).

**Why the limit is 150 ms.** An identify reply is short: after its first
token it streams for only about 0.6 s, and its full length varies between
runs (66–86 characters). With a 1000 ms limit, a cancel that did nothing
would still pass. The reply would just finish on its own about 300 ms
later, inside the limit, and it could even be a few characters shorter
than the control. The other M0.3 checks (no item returned, slot free) also
pass in that case, because the service releases the caller itself. A
150 ms limit sits well above the 6–25 ms seen when the cancel works, and
well below the roughly 300 ms of a reply that finishes on its own. So M0.3
now catches a cancel that doesn't stop. M0.4, with long replies, remains
the main proof of the stop timing.
- **Slot free:** the cancelled call returned within 1 ms. The next scan request
  was not rejected as `BUSY` and started generating 6–24 ms later.
- **Next identify is right:** a phone every time (`ponsel` or `ponsel pintar`).
- **The cancelled call returned no item:** `identifyItem` returned a
  failure, not a half-parsed result.

### Re-run with the 150 ms limit (2026-10-09, 00:40–00:48 WIB)

The same file, run 3 times in a row with nothing else running:

| Run | Control identify | Cancel fired | Chars when cancelled | Stream closed after cancel | M0.3 | M0.4, M0.5a, M0.5b |
|---|---|---|---|---|---|---|
| 1 | 79 chars, first token **4749 ms** | **after the identify had finished** (893 ms after it closed) | 76 / 79 | – | **failed: inconclusive** | passed (stream closed 17–37 ms after cancel) |
| 2 | 79 chars, first token 3602 ms | 476 ms after first token | **79 / 79** | 40 ms | **failed: reached full length** | passed (10–28 ms) |
| 3 | 76 chars, first token 3021 ms | 282 ms after first token | 46 / 76 | 26 ms | passed | passed (8–20 ms) |

**The 150 ms limit never failed.** Where it could be measured, the stream
closed 26 and 40 ms after cancel. Both M0.3 failures come from **where the
cancel landed**:

- **Run 1:** the warm control identify was unusually slow (first token at
  4749 ms, against 3021–3258 ms in every other run). So the cancel fired
  after the identify being tested had already finished. The test caught
  this as "inconclusive", as designed.
- **Run 2:** the identify being tested was about 226 ms faster than the
  control, so the cancel landed 476 ms into a reply that only streams for
  about 586 ms after its first token. It had already produced all 79
  characters. At that point a working cancel and a reply finishing on its
  own look the same, and the "fewer characters than the control" check
  failed.

The cause is that identify's first-token time drifts by 0.2–1.5 s from
one request to the next, while there is only a ~0.6 s window to cancel in.
The limit was not loosened. The retry method below was added in answer.

### M0.3 with retry (version 4, 2026-10-09, 01:29–01:58 WIB)

(Version 5 below sets the offset back to 250 ms; the rules here are unchanged.)

**Method.** One run makes at most 3 cancel attempts. Each attempt starts an
identify, cancels it 100 ms after the expected first token, then runs one
uncancelled identify (the slot-free check). The expected first token and
the full reply length come from the most recent uncancelled warm identify:
the control for attempt 1, then each attempt's follow-up identify. Each
attempt is classified from the service's own log, in this order:

1. No token before the cancel → **inconclusive** (landed before the first token).
2. The stream had closed at or before the cancel → **inconclusive** (the reply had finished).
3. The stream was open at the cancel but closed more than 150 ms after it →
   **fail at once, no retry** (landed mid-reply and did not stop).
4. Closed within 150 ms, but the reply already had full length →
   **inconclusive** (nothing was left to cut; run 2 above).
5. Otherwise **conclusive**, and the remaining checks run unchanged: no item
   returned, fewer characters than a full reply, next identify not busy and
   a phone.

If all 3 attempts are inconclusive, the run fails as inconclusive. The
150 ms limit and the other checks are unchanged.

**Results, 5 runs of the whole file in a row:**

| Run | M0.3 attempts (cancel landed, chars, stream closed after cancel) | Inconclusive used | M0.3 | M0.4 | M0.5a | M0.5b |
|---|---|---|---|---|---|---|
| 1 | 1: 103 ms after first token, 16/76, 13 ms, mid-reply | 0 | **passed** | passed (2–20 ms) | passed | passed |
| 2 | 1: 754 ms after first token, reply had finished 179 ms before the cancel → inconclusive. 2: 230 ms after, 35/86, 21 ms, mid-reply | 1 | **passed** | **failed: the Mac slept** (see below) | failed (after the sleep) | failed (after the sleep) |
| 3 | 1: 213 ms after, 37/79, 20 ms, mid-reply | 0 | **passed** | passed (2–27 ms) | passed | passed |
| 4 | 1: 267 ms after, 37/79, 6 ms, mid-reply | 0 | **passed** | passed (10–16 ms) | passed | passed |
| 5 | 1: before the first token → inconclusive. 2: 526 ms after, 77/76, 25 ms, full length → inconclusive. 3: before the first token → inconclusive | 3 | **failed: inconclusive** | passed (2–24 ms) | passed | passed |

- **No cancel that landed mid-reply ever failed to stop.** The 4 mid-reply
  M0.3 cancels closed the stream 6–21 ms after the cancel. Every M0.4 trial
  in this batch closed within 2–27 ms, and every M0.5b scan within 17–27 ms.
- **The 100 ms offset landed mid-reply in 4 of 8 attempts (50%).** The
  earlier 250 ms offset landed mid-reply in 10 of 12 (83%), counted the same
  way over versions 2, final, slot and the 150 ms re-runs. The drift in
  first-token time (actual landing ranged from before the first token to
  754 ms after it) is bigger than the offset. 100 ms mostly trades "reply
  already finished" misses for "before the first token" misses.

### Two observations from this batch (no change made)

1. **Test environment: the Mac slept during run 2.** It was first recorded
   as an unexplained native stall; the macOS power log (`pmset -g log`)
   explains it.
   - **What the test saw:** M0.4 trial 2's cancel itself worked (164 chars,
     stream closed 17 ms after cancel). The very next, uncancelled request
     then took about 15 minutes: the plugin logged `prefill 282ms + decode
     900407ms over 48 chunks`, about 0.1 chunks per second (normal is about
     30–43). The service's 120 s timeout, its `stopGeneration` call and the
     test's 5-minute timeout were all logged together just before the
     stream ended. M0.5a and M0.5b in that run failed only because they
     started on top of the leftover work.
   - **What the power log shows (WIB, 2026-10-09):**

     | Time | Event |
     |---|---|
     | 01:31:44 | run 2 starts |
     | 01:32:50 | display turned off |
     | 01:33:13 | DarkWake (a low-power state) due to Idle Sleep |
     | 01:34:25 | Sleep, then a 10 s DarkWake |
     | **01:34:35** | **Sleep due to Idle Sleep, 899 s** |
     | **01:49:34** | **Wake (trackpad/keyboard), display on** |
     | 01:49:39 | run 2 exits, 5 s after the wake |

   - **Why it matches:** the 899 s sleep matches the 900,407 ms decode, and
     the timers that fired together had been frozen during sleep.
   - **Likely related:** the slow follow-up identify earlier in the same run
     (first token at 11.8 s) falls in the display-off and DarkWake window
     (01:32:50–01:33:13). That's likely related, not proven.
   - **Not related:** the Spotlight re-indexing (about 97% CPU) also running
     then was not the cause. Run 3 ran under the same load with no stall.
   - **Fix for later runs:** run under `caffeinate -dimsu`, so the Mac can't
     sleep.
2. **A cancel during prefill only takes effect when prefill ends (run 5).**
   Prefill is the model reading the prompt, and for identify it includes
   encoding the photo. Twice the cancel fired before the first token. Both
   times the plugin reported `generation total: 3738ms (no chunks emitted)`
   and `9522ms (no chunks emitted)`, so the stream closed **379 ms** and
   **6057 ms** after the cancel, at the end of prefill. The service
   released the slot within 2–4 ms anyway. The plugin then made the next
   request wait for the stopped one, so it started 376 ms and 6073 ms after
   release. The 6 s case was during a slow episode: the next identify's
   prefill took 13.5 s. In short: cancelling a request that is still
   decoding is fast, but cancelling one still in prefill frees the slot at
   once while the engine stays busy until prefill ends. **Accepted as a
   known limit in decision 0003** (no change).

### M0.3 with retry at 250 ms, Mac kept awake (version 5, 2026-10-09, 02:12–02:25 WIB)

The same retry rules as version 4, with the offset set back to **250 ms**
after the expected first token. The 5 runs were done in a row under
`caffeinate -dimsu`, so the Mac could not sleep. They started only once no
Chrome media (audio or video) was playing, and no other Flutter or Gemma
process was running.

| Run | M0.3 attempt (cancel landed, chars, stream closed after cancel) | Inconclusive used | M0.3 | M0.4 (stream closed after cancel) | M0.5a | M0.5b | Stall |
|---|---|---|---|---|---|---|---|
| 1 | 186 ms after first token, 35/79, 29 ms, mid-reply | 0 | **passed** | passed (8–22 ms) | passed | passed | none |
| 2 | 375 ms after, 59/83, 20 ms, mid-reply | 0 | **passed** | passed (3–6 ms) | passed | passed | none |
| 3 | 152 ms after, 18/79, 9 ms, mid-reply | 0 | **passed** | passed (6–28 ms) | passed | passed | none |
| 4 | 348 ms after, 53/79, 19 ms, mid-reply | 0 | **passed** | passed (16–21 ms) | passed | passed | none |
| 5 | 328 ms after, 47/76, 12 ms, mid-reply | 0 | **passed** | passed (12–17 ms) | passed | passed | none |

- **M0.3 was conclusive on the first attempt in all 5 runs**, and every
  cancel stopped the stream within 9–29 ms. No retry was needed.
- **Over all batches, the 250 ms offset landed mid-reply in 15 of 17
  attempts**, against 4 of 8 at 100 ms.
- **Stall and environment checks:**
  - no stall: the slowest decode in the batch was 28.8 chunks per second
  - 0 `generation timeout` lines
  - the macOS power log shows no sleep or wake events from 02:12 to 02:25
  - per-minute samples showed no Chrome media and a load average of 2.1–4.2
- **M0.4 over all batches:** 72 trials, and the stream closed 2–38 ms after
  every cancel.
- **M0.5b in this batch:** the scan's stream closed 11–38 ms after the
  user request, and discuss's first token came 320–460 ms after it.

## M0.4: delay between cancel and the model being idle

Each trial asks for a hard multiple-choice question (a long reply, about
3.4–4.8 s), cancels it 1.5 s in, and immediately sends the same request
again as a probe. The probe shows when the engine is free again.

| Run · trial | Chars when cancelled / full | Stream closed after cancel | Probe started after it was sent | Probe first token | Cancel → probe first token |
|---|---|---|---|---|---|
| 1 · 1 | 209 / 586 | 7 ms | 8 ms | 318 ms | 327 ms |
| 1 · 2 | 143 / 586 | 38 ms | 46 ms | 282 ms | 330 ms |
| 1 · 3 | 151 / 586 | 25 ms | 34 ms | 317 ms | 352 ms |
| 2 · 1 | 231 / 621 | 19 ms | 21 ms | 229 ms | 250 ms |
| 2 · 2 | 236 / 621 | 20 ms | 21 ms | 318 ms | 340 ms |
| 2 · 3 | 236 / 621 | 30 ms | 33 ms | 320 ms | 353 ms |
| 3 · 1 | 219 / 734 | 3 ms | 5 ms | 251 ms | 256 ms |
| 3 · 2 | 234 / 734 | 10 ms | 12 ms | 326 ms | 338 ms |
| 3 · 3 | 217 / 734 | 6 ms | 8 ms | 326 ms | 334 ms |

| Measure | Range | Median |
|---|---|---|
| **Cancel → native stream closed** (engine stopped decoding) | **3–38 ms** | 19 ms |
| Cancel → next request starts generating | 5–46 ms | 21 ms |
| Cancel → next request's first token | 250–353 ms | 334 ms |
| Next request's own first-token time | 229–326 ms | 318 ms |
| Uncancelled control first-token time (first reply after load) | 534–675 ms | 649 ms |

The probe's own first-token time (229–326 ms) is normal. It is not longer
than an uncancelled reply, so the stopped generation leaves no hidden wait.
The controls are slower only because they are the first reply after loading
the model.

The 15 earlier trials (test versions 1 and 2, logs below) agree: the stream
closed 4–20 ms after cancel in every one. Across all 24 trials, the worst
case is 38 ms.

## Problems with my test, found and fixed (test code only)

- **Version 1, M0.3 inconclusive in all 3 runs.** The cancel was timed from
  the first identify after loading the model, which is about 0.8 s slower
  (cold). The warm identify being tested had already finished 328–444 ms
  before the cancel fired, so `cancel()` had nothing to cancel. There was no
  `canceling active request` line. Fixed by timing from a warm identify and
  adding the "stream still open at cancel" check.
- **Version 1 and 2, M0.4 failed twice on content, not cancel.** Gemma
  sometimes returns 5 answer options, which `_parse` rejects, and the test
  wrongly required the question to parse. Fixed: the control only has to
  produce non-empty text (trimmed, so whitespace-only fails), and the probe
  only has to stream. Whether the question parsed is now recorded, not
  asserted.
- **Version 3 (after the M0 review), M0.3 limit too loose.** As explained
  above, the 1000 ms "stream still open" limit could not catch a cancel that
  doesn't stop. It is now 150 ms. Same change: the M0.4 control check went
  from "at least one character" to "non-empty after trimming". The test
  takes that text from the parsed question, or from the service's
  `unparseable question (attempt 1): <text>` line, which logs the reply
  already trimmed.

## Other findings (no change made, for your decision)

1. **5-option questions.** In the final runs, 6 question attempts came back
   with 5 options. One question failed both attempts and returned `null`;
   in the app that means the fallback question is shown. This also happened
   on uncancelled first replies after a fresh model load, so it is not a
   cancel side effect. It belongs with the temperature test in plan item 1.3
   (production temperature is 0.9). None of the M0.1 runs hit it.
2. **After a cancel, the plugin adds the partial reply to the chat history**
   (`InferenceChat: Added to model history`). Every slot request uses
   `fresh: true` and clears the history first, so it doesn't leak into the
   next prompt today. A future request without `fresh: true` would see it.
3. **The plugin logs `Error during token calculation: Bad state: Session is
   closed`** after each cancel. It's caught inside the plugin, and the stream
   still ends cleanly.
4. **`cancel()` doesn't await `stopGeneration()`**
   (`try { _chat?.stopGeneration(); } catch (_) {}`). An async failure there
   would escape the `catch`. None happened in the 30 real cancels across all
   9 runs (each one logged `canceling active request`).

## Raw logs

Outside the repo, in `~/GITHUB/ELIO/elios-m0-logs/`:

- `c250-{1,2,3,4,5}.log` and `c250-samples.log`: version 5, the committed
  test (retry at 250 ms, under `caffeinate -dimsu`)
- `retry-{1,2,3,4,5}.log` and `retry-load-samples.log`: version 4 (retry
  at 100 ms; the run 2 sleep and the prefill observation)
- `fix1-{1,2,3}.log`: the 150 ms re-runs
- `slot-{1,2,3}.log`: the M0.5 runs (with M0.3 and M0.4 repeated)
- `cancel-final-{1,2,3}.log`: the tables in the M0.3 and M0.4 sections above
- `cancel-v2-{1,2,3}.log`: version 2 (M0.3 passed 3/3, M0.4 failed once on 5 options)
- `cancel-v1-{1,2,3}.log`: version 1 (M0.3 inconclusive because of timing)
