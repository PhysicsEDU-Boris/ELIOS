# 0005: Findings from M0, recorded, not fixed in M0

- Status: Accepted (record only; each fix is a later decision)
- Date: 2026-10-09
- Milestone: M0 (found while proving stage 2, plan 1.1)
- Evidence: real-model logs in `~/GITHUB/ELIO/elios-m0-logs/` (outside the
  repo): `run-{1,2,3}.log` (M0.1/M0.2) and `cancel-{v1,v2,final}-{1,2,3}.log`
  (M0.3/M0.4). Details in
  [`docs/test-results/m0-cancel.md`](../test-results/m0-cancel.md).

## Context

M0 allows no production change except the `stopGeneration` fallback, and
decision 0003 found that fallback is not needed. These three findings came up
along the way. They are recorded here with counts so they can be scheduled.
None of them is fixed in M0.

## Finding 1: multiple-choice questions that fail to parse

`GemmaQuizService._parse` (`gemma_quiz_service.dart:577`) only accepts valid
JSON with exactly 4 non-empty options and a `correctIndex` from 0 to 3.
`generateQuestion` tries twice, then returns `null`, and the app shows the
fallback question.

Counts across all 12 real-model runs (47 multiple-choice attempts: 44 in the
M0.4 sections and 3 in M0.1):

| | Count |
|---|---|
| Attempts rejected | **14 of 47 (30%)** |
| — 5 options | 12 |
| — 6 options (the 6th was a question line, "Pilihan mana yang paling tepat?") | 1 |
| — 4 options but invalid JSON (trailing comma after the last option) | 1 |
| Questions lost after both attempts (fallback shown) | **3 of 36 (8%)** |
| Rejections in uncancelled first replies after a fresh model load | 5 (so not caused by cancel) |
| Rejections in M0.1 (3 multiple-choice attempts) | 0 |

The essay questions (no options) never failed to parse in these runs.

**Recommendation:** fix it in the temperature test of plan 1.3, before M3.
Run the same prompt about 20 times at the current 0.9 and at one lower value
(0.3–0.4), and count valid 4-option JSON. If the lower value fixes it,
change the temperature (with your approval, per working rule 5). Do not
loosen `_parse`, for example by cutting the list to 4 options: the
`correctIndex` may point at a cut option, and the answer key would then be
wrong. The question bank in M3 (plan 2.1) removes most of this risk, since
questions will come from reviewed text rather than from generation.

## Finding 2: the cut-off reply stays in the chat history after a cancel

After a cancel, `flutter_gemma`'s `InferenceChat` still adds the partial
reply to its history (`InferenceChat: Added to model history`).

| | Count |
|---|---|
| Real cancels where the partial reply was added to history | **30 of 30** |
| Requests where it reached the next prompt | **0**, because every slot request (`identifyItem`, `generateQuestion`, `discuss`, `reviewEssay`) passes `fresh: true`, which clears the history first |

**Recommendation:** no change while every request uses `fresh: true`. If a
later milestone adds a request that keeps history (for example a multi-turn
chat in the M4 overlay), clear the history after a cancel in that path, and
add a test that cancels and then checks the next prompt doesn't contain the
cut-off text. Until then, add a one-line comment next to `fresh: true` when
M2 touches `_send`, so this invariant isn't lost.

## Finding 3: `cancel()` and `_send` don't wait for `stopGeneration()`

Three call sites (`gemma_quiz_service.dart:382`, `:408`, `:435`) do
`try { _chat?.stopGeneration(); } catch (_) {}`. `stopGeneration()` returns
a `Future`, and nothing waits for it. So an error inside it would not be
caught by that `catch`. It would surface as an unhandled async error.

| | Count |
|---|---|
| Real cancels | 30 |
| Unhandled errors from `stopGeneration` | **0** (no `Unhandled Exception` in any of the 12 logs) |

**Recommendation:** low risk on macOS today, but fix it in M2, when the
state machine touches this code. Make the three calls explicitly
fire-and-forget with their own error handler, for example
`unawaited(_chat?.stopGeneration().catchError((_) {}))`. That doesn't change
timing: the slot is still released at once, and 0003 shows the engine
stops within 38 ms anyway. Re-run `integration_test/gemma_cancel_test.dart`
afterwards. Check it on Android in M5, where plugin errors are more likely.
