# 0011: Background quiz prefetch — only question 1 may make the student wait (M2b part 3)

- Status: Accepted
- Date: 2026-10-15
- Milestone: M2b (Notion plan 1.2, stage 3b, third part; follows decisions
  0009 and 0010)
- Code:
  - `lib/services/gemma_quiz_service.dart` (`_tryGenerateQuestion`,
    `generateQuestionBackground`, the `'CANCELLED'` sentinel)
  - `lib/providers/waste_quiz_provider.dart` (`_startPrefetch`,
    `_runPrefetch`, `_generateForBuffer`, `_cancelPrefetch`,
    `_consumeQuestion`)
  - `lib/widgets/waste_quiz_popup.dart` ("Menyiapkan soal berikutnya…")
  - `lib/services/live_scan_controller.dart`,
    `lib/widgets/live_scan_debug_overlay.dart` (`nextWaitMs`)
- Tests: `test/quiz_behavior_test.dart` (group "M2b part 3: background quiz
  prefetch")

## Context

Owner's decision for this task: the quiz appears right after the scan, and
any wait happens only before question 1 — questions 2-5 must appear with no
wait. Two things needed to be understood first.

### (a) How the quiz flow worked before this change

Questions per session came from `QuizDifficulty.questionCount` (easy=1,
medium=3, hard=5). Every question — including 2 through N — was generated
**on tap**: `_loadQuestion(index)` ran once for question 1 from
`_startSession`, and again for every later question via
`_advance() → _loadQuestion(questionIndex + 1)`, itself called from
`nextQuestion()`/`skipQuestion()`. Nothing was precomputed; the model always
ran after the tap, inside the button handler. Essay vs. multiple-choice was
decided purely by index parity, before generation even started:
`questionTypeFor(index) => index.isEven ? multipleChoice : essay`.

### (b) Why "SOAL CADANGAN (AI ON-DEVICE BELUM SIAP)" showed up for questions
2-4 while the student was chatting (robot test, 2026-10-14)

The next-question request got **BUSY**, not cancelled — and the badge text
doesn't distinguish why. In `GemmaQuizService._send`, a non-user call
(`generateQuestion`, `isUser: false`) that finds the slot active returns
`'BUSY'` at once, with no retry and no queueing; only an `isUser: true`
caller gets to queue behind / preempt the active request (decision 0003).
So while the student's chat (`discuss()`, `isUser: true`) held the slot,
`_loadQuestion`'s `generateQuestion` call for the next question got `'BUSY'`
→ returned `null` → `_fallbackQuestion` was used. The badge itself
(`waste_quiz_popup.dart`, `isFallback`) is one static string regardless of
cause, so a busy-but-fully-loaded model looked identical to an unloaded one.
The model was never actually unavailable — the single generation slot was
just occupied by the student's own chat.

## Decision

### 1. Background prefetch, one slot, lowest priority

As soon as question 1 is shown (`_loadQuestion(0)` reaches `active`),
`WasteQuizNotifier._startPrefetch()` pre-allocates one
`Completer<GeneratedQuestion?>` per remaining index (1..N-1) and starts
`_runPrefetch`, which generates them **sequentially**, one at a time,
through `GemmaQuizService.generateQuestionBackground` — the same single
Gemma slot every other request uses, so it inherits the existing busy/queue
rules for free: a background call (`isUser: false`) never preempts a user
request, and always loses the slot to one.

`"Soal berikutnya"` (`_consumeQuestion`) just `await`s the completer for the
index it needs: instant if it's already done, or waits while showing
"Menyiapkan soal berikutnya…" if not. It never starts a second, redundant
generation for the same index.

### 2. Priority and "never a fallback from a chat message"

`_generateForBuffer` loops: on each attempt, if `generateQuestionBackground`
reports `retry: true` (the slot was busy, or this very call got cancelled by
a higher-priority request), it waits 300 ms and tries again — it does **not**
give up and does **not** report a failure. It only returns once an attempt
is truly terminal: a real question, or a genuine failure (model not ready,
timeout, or parse/duplicate exhausted both attempts).

This required telling "cancelled by a higher-priority request" apart from
"a real failure", which the service previously could not do — both looked
like a plain `null`. `GemmaQuizService._send`'s two force-complete sites (the
"user request cancels an active scan" branch, and `cancel()`) now complete
the cancelled caller with the string `'CANCELLED'` instead of `null`.
`identifyItem`, `discuss` and `reviewEssay` treat it exactly like `null`
(no behaviour change for them); only the new
`_tryGenerateQuestion`/`generateQuestionBackground` path reads it to mean
"retry", alongside the existing `'BUSY'` sentinel.

Net effect: a chat message or essay grading (both `isUser: true`) always
preempts an active background prefetch at once (unchanged, decision 0003's
existing mechanics) — but now the prefetch **resumes** afterwards instead of
surfacing a fallback. Closing the quiz (`dismiss()`) or starting a new
session (`_startSession`/`onPhotoCaptured`) calls `_cancelPrefetch()`:
increments a generation counter every retry loop checks, and completes any
still-pending completer with `null` — so prefetch stops and the buffer is
cleared, not kept alive across sessions.

### 3. No duplicates

The prompt already carried an "avoid these" list (`_askedQuestions`); this
is now populated eagerly — as soon as a question is *generated* (shown or
still sitting in the buffer), not only when it's *displayed* — so prefetching
question 3 avoids question 2 even before the student has seen it. On top of
that, `_tryGenerateQuestion` now rejects a parsed question that
case/punctuation-normalizes to an exact match of one already in `avoid`,
and retries (same 2-attempt budget as an unparseable reply).

`ponytail`: this only catches near-exact repeats, not paraphrases — the
prompt's own "don't repeat these" instruction is the first line of defence.
If paraphrased repeats turn out to matter in practice, upgrade to a looser
similarity check then.

### 4. Not-ready and real-failure states

While `_consumeQuestion` awaits a not-yet-resolved completer, the popup
shows "Menyiapkan soal berikutnya…" (new case in `_QuestionCard`'s loading
switch, gated on `questionIndex > 0` so it doesn't collide with question 1's
"Gemma sedang membuat soal…" or the install/loading messages). A genuine
failure (not busy, not cancelled) still shows the existing fallback-question
path exactly once, with the existing honest "AI belum bisa membuat soal…"
text — unchanged from before this decision.

### 5. Parse retry

Already free: `_tryGenerateQuestion`'s existing 2-attempt loop (shared by
`generateQuestion` and `generateQuestionBackground`) already retries once on
an unparseable reply. No separate background-specific retry loop was added.

### 6. Measurement

`_consumeQuestion` times the wait with a `Stopwatch` (0 when the completer
was already done) and logs it per question
(`[WasteQuiz] ...: question N/total (type) waited Xms, first token Yms,
fallback=...`), mirroring decision 0010's per-question log but labelled
`waited` instead of `in` (question 1 still logs `in Xms`, since it's a fresh
generation, not a wait). `WasteQuizNotifier.lastNextWaitMs` exposes the same
number; wired into `LiveScanController`/`LiveScanDebugOverlay` as `next N ms`,
the same pull-callback pattern as `ttsCount`/`firstTokenMs`.

## Out of scope

- Prefetching beyond the current session (e.g. pre-warming the *next*
  scan's question 1) — not asked for, and the object isn't known yet.
- Changing `_askedQuestions`' potential duplicate entries (a question can be
  added once by the prefetch loop and once again when displayed) — harmless
  prompt-text redundancy, not worth extra code to dedupe the list itself.
- A real robot check of the "next … ms" numbers — the overlay field and the
  debug log are what the next robot session needs to show whether the fix
  holds under real model latency and real Wi-Fi chat timing.

## Consequences

- No change to question 1's behaviour or timing — it's still a plain
  foreground `generateQuestion` call, same as before this decision.
- `GemmaQuizService.generateQuestion` is unchanged in observable behaviour
  (still returns `null` for busy/cancelled/failed alike); its internals now
  share `_tryGenerateQuestion` with the new `generateQuestionBackground`.
- Tests: `test/quiz_behavior_test.dart`, group "M2b part 3: background quiz
  prefetch" — buffer order (sequential, avoid-list growing), instant from
  the buffer (no new generation call), a tap before the buffer is ready
  (waits, then shows — never a fallback), a chat message pausing and
  resuming prefetch with no fallback, closing the quiz cancelling prefetch,
  a near-duplicate question rejected, an unparseable reply retried.
  Break-checked: "instant from buffer" (reverted `_advance()` to call
  `_loadQuestion` again), "close cancels" (removed the `_cancelPrefetch()`
  call from `dismiss()`), and "chat doesn't cause fallback" (made a
  cancelled background attempt report `retry: false`) — all three failed
  against the reverted code, then were restored and re-verified green.
