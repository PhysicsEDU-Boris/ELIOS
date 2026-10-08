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
  16–38 of 79 characters.
- **Slot free:** the cancelled call returned within 1 ms. The next scan request
  was not rejected as `BUSY` and started generating 6–24 ms later.
- **Next identify is right:** a phone every time (`ponsel` or `ponsel pintar`).
- **The cancelled call returned no item:** `identifyItem` returned a
  failure, not a half-parsed result.

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
  produce tokens, and the probe only has to stream. Whether the question
  parsed is now recorded, not asserted.

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

- `cancel-final-{1,2,3}.log`: the committed test version (the results above)
- `cancel-v2-{1,2,3}.log`: version 2 (M0.3 passed 3/3, M0.4 failed once on 5 options)
- `cancel-v1-{1,2,3}.log`: version 1 (M0.3 inconclusive because of timing)
