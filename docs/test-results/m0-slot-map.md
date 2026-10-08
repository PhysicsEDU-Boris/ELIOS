# M0 slot map: the single Gemma slot

Date: 2026-10-08. Built with CodeGraph (`codegraph explore`) for the first
pass, then confirmed line by line against the current source in
`lib/services/gemma_quiz_service.dart` and `lib/providers/waste_quiz_provider.dart`
(CodeGraph can miss dynamic calls, so every entry below was checked by
reading the code; this map is not test evidence — the real proof is the
timings and the cancel test in M0.1 to M0.4).

## The slot itself

`GemmaQuizService` (singleton, `GemmaQuizService.instance`) holds exactly one
generation at a time through three fields (`lib/services/gemma_quiz_service.dart:129-132`):

| Field | Type | Meaning |
|---|---|---|
| `_activeCompleter` | `Completer<String?>?` | The request currently running `_chat.generateChatResponseAsync()`. Not null ⇒ slot busy. |
| `_activeIsUser` | `bool` | Whether the active request is a user request (`discuss`, `reviewEssay`) vs. a scan request (`identifyItem`, `generateQuestion`). |
| `_pendingCompleter` / `_pendingTask` | `Completer<String?>?` / `Future<String?> Function()?` | At most one request waiting its turn — only ever a user request (see below). |

All of `identifyItem`, `generateQuestion`, `discuss` and `reviewEssay` funnel
through `_send` (`gemma_quiz_service.dart:399`), which is the only place that
reads or sets `_activeCompleter`.

## Slot rules, as coded (`_send`, lines 399-427)

```
_activeCompleter == null                → run now via _executeSend (line 426)
_activeCompleter != null, isUser=false   → return 'BUSY' immediately (line 403), nothing queued
_activeCompleter != null, isUser=true:
    _activeIsUser == false (a scan is running) → cancel it: stopGeneration + complete(null) (lines 407-411)
    _activeIsUser == true  (a user req is running) → leave it running
    then: replace _pendingCompleter/_pendingTask with this new user request (lines 414-417)
         (drops whatever was previously pending, completing it with null first)
```

So: a second **scan** request while busy is rejected with `'BUSY'`, never
queued. A **user** request (`discuss`/`reviewEssay`) always cancels a running
**scan** request, and always becomes the one pending slot — only one user
request can be queued at a time; a newer one bumps an older queued one.

When the active request finishes (`_executeSend`'s `finally`, lines 385-396),
if a pending task exists it is started immediately and its result wired to
the pending completer.

`identifyItem` and `generateQuestion` call `_send(..., isUser: false)` — scan
requests. `discuss` and `reviewEssay` call `_send(..., isUser: true)` — user
requests. This matches the acceptance check "a user request (discuss)
cancels a running scan request" and "a scan request while busy gets BUSY".

## Every call to `stopGeneration`

All three are inside `gemma_quiz_service.dart`, wrapped in `try {} catch (_) {}`
(a failed stop is swallowed, not surfaced) — no other file touches `_chat`
directly, confirmed by `git grep -n stopGeneration -- lib test integration_test`.

| Line | In | Fires when |
|---|---|---|
| 382 | `_executeSend`'s timeout handler | the 120s generation timeout trips |
| 408 | `_send`, yielding to a user request | a scan request is running and a user request arrives |
| 435 | `cancel()` | any external caller cancels the active request |

M0.3 must confirm whether this call actually stops LiteRT-LM generation, or
only requests it (see the open item in the Notion plan, section 1.1).

## `cancel()` (line 429) — every caller

Clears the pending slot unconditionally, and if a request is active, stops it
and completes it with `null`.

| Caller | File:line | Why |
|---|---|---|
| `WasteQuizNotifier.onDetections` | `waste_quiz_provider.dart:157` | a new MaixCAM2 label locks in, before starting its own session |
| `WasteQuizNotifier.onPhotoCaptured` | `waste_quiz_provider.dart:168` | a new phone-camera scan starts |
| `WasteQuizNotifier.startForLabel` | `waste_quiz_provider.dart:201` | test-mode "pick a label" scan starts |
| `WasteQuizNotifier.dismiss` | `waste_quiz_provider.dart:414` | the quiz popup is closed |
| `quiz_behavior_test.dart` | lines 108, 150, 162 | unit tests exercise cancellation directly |

`dispose()` (line 611) also calls `cancel()` as its first step, but nothing
in `lib/` calls `dispose()` on the Gemma slot today (`control_screen.dart` and
`device_scan_screen.dart` call `GemmaQuizService.instance.dispose()`, which is
the same method — confirmed above under "entry points").

## Entry points (who calls identify / discuss, and from where)

```
UI                                   Provider (WasteQuizNotifier)         Slot (GemmaQuizService)
──────────────────────────────────── ───────────────────────────────────  ─────────────────────────────
control_screen.dart:85               onDetections(detections)        ──►  cancel()
  (MaixCAM2 detection stream)                                              then identifyItem is NOT called
                                                                            here — label is used as-is
                                                                            (ScannedWaste.fromLabel), no
                                                                            Gemma identify call on this path

device_scan_screen.dart:63           onPhotoCaptured(imageBytes)     ──►  cancel()
debug_phone_camera_sheet.dart:41       │                                  then identifyItem(imageBytes)
  (phone-camera frame)                 ▼                                    (isUser: false — a scan request)
                                  _identifyThenQuiz(imageBytes, gen)
                                        │
                                        ▼
                                  _loadQuestion(index) ─────────────── ►  generateQuestion(...)
                                                                            (isUser: false — a scan request)

device_scan_screen.dart:211          startForLabel(label)            ──►  cancel()
  ("Uji tanpa kamera" test button)                                        (no identify call — label is
                                                                            already known; goes straight
                                                                            to generateQuestion)

waste_quiz_popup.dart:157            sendChatMessage(text)           ──►  discuss(...)
  (chat input in the quiz popup)                                          (isUser: true — a user request)

waste_quiz_popup.dart:319            submitEssay(answerText)         ──►  reviewEssay(...)
  (essay submit button)                                                   (isUser: true — a user request)

control_screen.dart:161              dismiss()                       ──►  cancel()
  (closing the quiz popup)
```

Only the **phone-camera** path (`onPhotoCaptured`) calls `identifyItem` — the
MaixCAM2 path (`onDetections`) trusts the detector's label and never asks
Gemma to identify the object (plan item 1.3's open question: detector label
vs. Gemma category).

## What this map does not prove

- Whether `stopGeneration` really halts the model (M0.3) — this map only
  shows where it's called, not what it does.
- Timing (M0.1) or a real (non-mock) cancel test (M0.2) — those need the
  integration test run, not static analysis.
- `mockSendExecute` (line 135, `@visibleForTesting`) lets
  `test/quiz_behavior_test.dart` substitute `_executeSend` without touching
  the real model — useful for the slot-rule tests (M0.4), but any result
  using it is a mock result, not proof for M0.1–M0.3.
