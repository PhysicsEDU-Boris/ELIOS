# 0004: The stage 2 commit is documented, not split

- Status: Accepted
- Date: 2026-10-09
- Milestone: M0 (plan 1.1, last item: "split or document the single stage 2 commit")
- Commit: `5289c8b` "Stage 2: Single Gemma slot, streaming, and
  cancellation" (was `664b0a3` before the history rewrite, see 0001)

## Context

Stage 2 landed as one commit touching 3 files (+212 / −37):

| File | Change |
|---|---|
| `lib/services/gemma_quiz_service.dart` | +130 / −37 |
| `lib/providers/waste_quiz_provider.dart` | +8 |
| `test/quiz_behavior_test.dart` | +74 |

It mixes four topics. Splitting it would mean rewriting history that is
already pushed: `5289c8b` is on `origin/feature/live-scan` and, as an
ancestor, on `origin/chore/repo-setup` (PR #1). Working rule 2 forbids
rewriting pushed history without your approval.

## Decision

Keep the commit as it is, and describe it here by topic, so it can be
reviewed one topic at a time.

## What the commit does, by topic

Line numbers are in the current `gemma_quiz_service.dart`. The full map of
callers is in [`docs/test-results/m0-slot-map.md`](../test-results/m0-slot-map.md).

### 1. One slot instead of a queue

- **Before:** `_serial()` chained every request onto `_queue`, so requests
  ran one after another. Nothing was rejected, and nothing could be
  cancelled.
- **After:** `_activeCompleter`, `_activeIsUser`, `_pendingCompleter` and
  `_pendingTask` (lines 129–132) implement the rules in `_send` (line 399):
  - A scan request while busy gets `'BUSY'`.
  - A user request cancels a running scan request.
  - At most one user request waits; a newer one replaces an older one.
  - `cancel()` (line 429) clears the waiting request and stops the active one.
  - `identifyItem` and `generateQuestion` are scan requests
    (`isUser: false`); `discuss` and `reviewEssay` are user requests
    (`isUser: true`).
- **Proven in M0:** [`m0-slot-rules.md`](../test-results/m0-slot-rules.md),
  [`m0-cancel.md`](../test-results/m0-cancel.md), decision 0003.

### 2. Streaming inside the service

- **Before:** `generateChatResponse()` returned the whole reply.
- **After:** `generateChatResponseAsync()` (line 350) is read token by
  token. The service logs first-token and total time, and the 120 s
  timeout now also calls `stopGeneration()` (line 382).
- **Not used yet:** the new `onToken` parameter is passed by no caller, so
  every caller still gets the full text at the end. Showing the reply as it
  arrives is still open (plan 1.3, "show a Looking... state and stream the
  output").
- **Proven in M0:** first-token timings in
  [`m0-timings.md`](../test-results/m0-timings.md).

### 3. Cancel wired into the quiz flow

In `waste_quiz_provider.dart`:

- `GemmaQuizService.instance.cancel()` is called in `onDetections`,
  `onPhotoCaptured`, `startForLabel` and `dismiss`.
- `_identifyThenQuiz` returns to idle when identify answers `busy`.

In the service, `dispose()` now calls `cancel()` first.

- **Proven in M0:** the slot map confirms every caller. The cancel
  behaviour itself is proven by M0.3.

### 4. Test hook and unit tests

- `mockSendExecute` (line 135, `@visibleForTesting`) lets unit tests replace
  the model.
- The commit adds 4 mock-based tests in `test/quiz_behavior_test.dart`.
  They check the logic only, so they are not proof on their own. They pass
  in M0.6.
- The test named `slot released after cancel/timeout/exception` only
  exercises cancel, not timeout or an exception.

## Small things noticed while documenting (not changed in M0)

- **The `dispose()` comment is out of date.** It says "Waits for any
  in-flight load or generation". Since this commit, `dispose()` cancels the
  generation and waits only for an in-flight load (`await _queue` was
  removed).
- **A comment explaining why was dropped.** The commit removed "Never
  silently drop a photo: a text-only model asked about an image just
  guesses (it kept answering 'plastic bottle')". The check it explained is
  still there (line 339), so only the reason is lost.

Both are one-line comment fixes for when M2 touches this file.

## How to review it by topic

```bash
git show 5289c8b -- lib/services/gemma_quiz_service.dart   # topics 1, 2, part of 3
git show 5289c8b -- lib/providers/waste_quiz_provider.dart # topic 3
git show 5289c8b -- test/quiz_behavior_test.dart           # topic 4
```

## Consequences

- History stays as pushed, and no hashes change again.
- Future work follows the "one topic per commit" rule from the start (M1
  onward).
