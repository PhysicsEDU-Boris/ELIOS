# 0010: One TTS slot, no stale overlay numbers, a monotonic default clock (M2b part 2)

- Status: Accepted
- Date: 2026-10-14
- Milestone: M2b (Notion plan 1.2, stage 3b, second part; follows decision
  0009, camera-stays-alive)
- Code:
  - `lib/services/quiz_tts_service.dart`
  - `lib/providers/waste_quiz_provider.dart` (`_appendAiReply`, `_loadQuestion`)
  - `lib/services/live_scan_controller.dart` (first-token/question reset, `ttsCount`)
  - `lib/services/detection_stabilizer.dart` (`monotonicClock()`, shared)
  - `lib/widgets/live_scan_debug_overlay.dart`
  - `docs/decisions/0003-stop-generation.md` (the `cancel()` await — covered there, not here)
- Tests:
  - `test/quiz_behavior_test.dart` (TTS group, cancel group)
  - `test/live_scan_controller_test.dart` (first-token/question reset, default clock)
  - `test/live_scan_state_machine_test.dart`, `test/detection_stabilizer_test.dart` (default clock)

## Context

Four smaller M2b findings, from code review rather than a new robot
recording:

1. TTS behaviour (one slot, no repeats, stop on close) had never been
   checked against code, only assumed.
2. The overlay's `first token`/`question` fields only ever get *set*, never
   *reset* — decision 0008 already flagged this as a known limit
   ("stale after a fallback question").
3. The stabilizer, state machine and controller default to wall-clock
   `DateTime.now` unless a caller injects a clock. `LiveScanController`
   already injects a monotonic one into both (so production is unaffected
   today), but the *defaults themselves* aren't monotonic — a future caller
   that constructs either class directly would silently lose that
   protection.
4. The one slow question in the 2026-10-14 robot recording (11.3 s vs.
   5.0–5.8 s for the rest of that session) had no record beyond the debug
   overlay's live numbers — nothing to look back at after the fact.

## Decision

### 1. TTS: one slot, keyed by object

Checked every place the quiz speaks (`flutter_tts`, via `QuizTtsService`,
the only wrapper around it — `grep` found no other `FlutterTts` use):

- **One slot, new stops old:** already true. `QuizTtsService.speak()`
  always `await stop()`s before dispatching the new utterance; there's one
  `FlutterTts` instance behind the singleton, so nothing can overlap. No
  change needed; locked in by a test.
- **Closing the quiz stops speech:** already true.
  `WasteQuizNotifier.dismiss()` already calls
  `unawaited(QuizTtsService.instance.stop())`. No change needed; locked in
  by a test.
- **Same text not repeated within a quiz:** this *was* a gap. Every
  `_appendAiReply` call site is a discrete event handler (not `build()`),
  so a plain widget rebuild can't call it again — but nothing stopped the
  *same* text being appended (and spoken) twice from two different event
  handlers (for example two chat messages sent before answering both get
  the identical "answer first" reply). `WasteQuizNotifier` now tracks
  `_lastAutoSpokenText`; `_appendAiReply` skips `speak()` when the new text
  matches it, and `_freshSession` (a new object/quiz) resets it to null so
  the new quiz starts clean. The **manual "Listen" button** (`listen()`,
  used by `_QuizCard._listen`) is untouched — pressing it again must still
  replay the same text on purpose.
- **Debug overlay "tts N":** `QuizTtsService.startedCount` counts every
  `speak()` call that passed the empty-text check (even if the
  dedup guard above then skips dispatching it — a count of "would have
  spoken" is what proves TTS *tried* to run in a screen recording with no
  audio, which is the stated reason for this field). Wired into
  `LiveScanController` the same way `lastFirstTokenMs` already is: a pull
  callback (`ttsCount: () => QuizTtsService.instance.startedCount`) read on
  every overlay rebuild, not a push.

### 2. The overlay no longer shows a stale first-token/question time

Two different staleness paths, both closed:

- **Between asks:** `lastFirstTokenMs`/`lastAskToQuestionMs` used to stay
  at whatever the *previous* ask set them to until the *current* ask's
  question showed. Now `LiveScanController.onDetections` resets both to
  `null` the instant a new ask succeeds (`startQuiz` returns true), before
  any `onQuizPhase` call for it — so the overlay reads "-" for the whole
  ASKING window, not the last quiz's numbers.
- **A fallback or an early-failing generation:** `GemmaQuizService`'s
  `lastFirstTokenMs` notifier used to be set only in `onDone`, on a
  successful stream. A call that returns early — `ensureReady` fails, the
  slot is BUSY, no image encoder, or (relevant here) `generateQuestion`
  exhausts its 2 parse attempts and `_loadQuestion` falls back to
  `_fallbackQuestion` — never reaches `onDone`, so the notifier kept
  whatever an *earlier*, unrelated generation had left there.
  `_executeSend` now resets it to `null` at the very top, before
  attempting anything, so every call's outcome (including "never
  streamed") is accurate by the time a caller reads it.

Both numbers can still look identical to a casual glance in the single
most common case (a normal, successful question) — the fix only matters
for the fallback/failure case, which is exactly what decision 0008 flagged
as a known limit and what the task asked to close.

### 3. Monotonic clock by default, everywhere

`DetectionStabilizer`, `LiveScanStateMachine` and `LiveScanController` each
default their clock to `DateTime.now` unless one is injected.
`LiveScanController` already built and passed down a `Stopwatch`-based
clock to both (so production was never actually exposed to this), but the
*defaults* themselves weren't monotonic — anyone constructing
`DetectionStabilizer()` or `LiveScanStateMachine(stabilizer)` directly, now
or later, would silently fall back to wall-clock time, which a system
clock change, DST, NTP sync, or the user changing the time could disrupt.

A single `monotonicClock()` function now lives in `detection_stabilizer.dart`
(the common import of all three files) and is the default in all three
constructors. The injectable fake clock used by every test is unchanged.

### 4. Per-question timing log

In debug builds, `_loadQuestion` (`waste_quiz_provider.dart`) now
`debugPrint`s one line per question load:

```
[WasteQuiz] Cardboard: question 4/5 (essay) in 11337ms, first token 299ms, fallback=false
```

Label, `index+1/total`, question type, elapsed wall time for the load,
first-token time (from `GemmaQuizService.lastFirstTokenMs`, read right
after `generateQuestion` returns — now accurate per the staleness fix
above), and whether it fell back. One line per *question*, not per quiz,
so a slow question inside an otherwise-fast multi-question session (like
the 11.3 s one) is pinpointed by its own index, not averaged away.

## Out of scope

- Hazard handling (M2b, still open per decision 0008).
- Re-tuning anything (scores, cooldowns, waits) — none of the anti-spam
  thresholds changed.
- A real robot check of the 11.3 s question recurring — the timing log
  (above) is what the next long session needs to show whether it does.

## Consequences

- No behaviour change in the common case (a real question, no cancel,
  normal object handling) beyond what's described above.
- The overlay and the debug log are the only user-visible changes; no
  widget/UI layout changed.
- `cancel()`'s own timing change is recorded in decision 0003's update
  (2026-10-14), not duplicated here.

## Update, 2026-10-15 (PR #16 robot-test follow-up): "Soal berikutnya"/skip now stop TTS too

Found while analysing the PR #16 (decision 0011) robot recording: the
"one slot, new stops old" rule above only ever fires when something new is
*spoken* (`QuizTtsService.speak()` stops first). Showing a *question* was
never itself a `speak()` call (only an answer verdict, essay-grading reply,
or chat reply is, via `_appendAiReply`), so nothing stopped a still-playing
reply when the question changed underneath it. Checked every path that
changes the question:

- `WasteQuizNotifier._loadQuestion` (question 1): no stop call.
- `WasteQuizNotifier._consumeQuestion` (questions 2+, reached from both
  `nextQuestion()` and `skipQuestion()` via `_advance()`): no stop call.
- `dismiss()`: already called `QuizTtsService.instance.stop()` — unaffected.

So tapping "Soal berikutnya" or skip while a verdict/chat/essay-grading
reply was still being read aloud left that voice playing over the new
question, with nothing to cut it off. Fixed: both `_loadQuestion` and
`_consumeQuestion` now call `unawaited(QuizTtsService.instance.stop())`
first thing, unconditionally (not gated by `voiceOn` — same as `dismiss()`'s
existing call). `QuizTtsService.stop()` is already safe to call when
nothing is playing (`try`/`catch` around `_tts.stop()`).

**Test-only side effect:** this made `QuizTtsService.instance` (a lazily
constructed singleton wrapping `FlutterTts()`) get touched from
`test/live_scan_controller_test.dart`, which never called
`TestWidgetsFlutterBinding.ensureInitialized()` — `FlutterTts()`'s
`setMethodCallHandler` asserts the binding exists. Added that call,
matching every other test file. No other file needed it.

Tests: `test/quiz_behavior_test.dart`, "TTS: one slot…" group — `mockStop`
asserts a stop call on both `nextQuestion()` and `skipQuestion()`, and that
a stop call when nothing was ever spoken changes nothing else (the quiz
still advances). Break-checked: removing either new call made its matching
test fail (`Expected: a value greater than or equal to <1>`, `Actual: <0>`),
then both were restored and re-verified green.
