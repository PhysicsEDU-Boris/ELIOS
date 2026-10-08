# M0.5: slot rules on the real model

- **Date:** 2026-10-09 (runs 00:25–00:32 WIB)
- **Device / build:** macOS 27.0 (26A428), arm64, Flutter 3.44.2, **Debug**, `PreferredBackend.gpu`
- **Model:** `gemma-4-E2B-it.litertlm`
- **Test:** `integration_test/gemma_cancel_test.dart`, tests `M0.5a` and `M0.5b`.
  Real model, no mock, no production change. The whole file (M0.3, M0.4,
  M0.5a, M0.5b) was run 3 times in a row with nothing else running.
- **Result:** 3 of 3 runs, all 4 tests passed.

The rules being proven come from `_send` (`gemma_quiz_service.dart:399`), see
[`m0-slot-map.md`](m0-slot-map.md). The existing unit tests in
`test/quiz_behavior_test.dart` cover the same rules with `mockSendExecute`.
Those are mock-only results and don't count as proof.

## M0.5a: a scan request while busy gets BUSY at once and is not queued

An identify starts, and 1.5 s later (while it's still running) both scan
entry points are called: a second `identifyItem` and a `generateQuestion`.

| Run | Busy identify | Busy question | The running identify | Generations in total |
|---|---|---|---|---|
| 1 | `busy` in 3 ms | `null` in 0 ms | ponsel | 1 |
| 2 | `busy` in 0 ms | `null` in 1 ms | ponsel | 1 |
| 3 | `busy` in 1 ms | `null` in 0 ms | ponsel | 1 |

- **BUSY, not waiting:** both rejected calls came back within 3 ms, while the
  running identify still had 2.4–3.0 s to go (it took 3.85–4.49 s in total). The service logged `slot
  busy, rejecting scan request` once for each.
- **Not queued:** after the running identify finished, the test waited 3 s
  more. Exactly one generation happened in total, so neither rejected
  request ran later.
- **The running request was not disturbed:** it still returned a phone.

## M0.5b: a user request (discuss) cancels a running scan request

A hard multiple-choice question (a scan request) starts, and 1.5 s later,
while it's mid-generation, `discuss` (a user request) is called.

| Run | Scan caller released | Scan stream closed | Scan text when stopped | Discuss started | Discuss first token | Reply |
|---|---|---|---|---|---|---|
| 1 | 1 ms | 21 ms | 213 chars | 23 ms | 296 ms | 347 chars |
| 2 | 1 ms | 6 ms | 227 chars | 7 ms | 291 ms | 487 chars |
| 3 | 2 ms | 24 ms | 267 chars | 26 ms | 345 ms | 347 chars |

All times are from the moment `discuss` was called.

- The service took the yield-to-user path exactly once per run (`canceling
  active scan request to yield to user request`).
- The scan returned `null` (no question), and its native stream closed within
  6–24 ms, partway through (213–267 chars of a reply that is normally 540–780).
- Discuss started 7–26 ms later and returned a plain-text reply (no JSON).
  The user waits **291–345 ms** for the first token of the answer, which is
  close to a normal discuss first-token time (288–371 ms in M0.1).

## Same runs, cancel re-checked

The same 3 runs repeated M0.3 and M0.4 on the committed test file. M0.3
passed 3/3 (next identify: ponsel, ponsel, ponsel pintar). In the 9 M0.4
trials the stream closed 3–28 ms after cancel, inside the 38 ms worst case
in [decision 0003](../decisions/0003-stop-generation.md).

## Not covered

- What happens when a user request arrives while another **user** request is
  running. The code queues it in the one pending slot, and a newer user
  request replaces an older queued one. The plan didn't ask for it, so it
  isn't tested on the real model. The unit tests don't cover it either.
- Android, Release builds: see decision 0003.

## Raw logs

`~/GITHUB/ELIO/elios-m0-logs/slot-{1,2,3}.log` (outside the repo).
