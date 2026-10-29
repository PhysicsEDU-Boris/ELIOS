# 0041: Faster photo identify, "Bukan ini?" picker, background Gemma load (E1)

- Status: Accepted (app and tests; phone timings NOT measured, see below)
- Date: 2026-10-29
- Amends: 0040 (the tester build no longer waits for the first request to load Gemma on the phone scan screen).
- Code: `lib/services/gemma_quiz_service.dart` (`identifyItem`, `warmUp`, `identifyMaxSide`),
  `lib/services/frame_source/viewfinder_crop.dart` (`downscaleJpeg`), `lib/providers/waste_quiz_provider.dart`
  (`canCorrectItem`, `correctItem`), `lib/widgets/waste_quiz_popup.dart`, `lib/services/question_bank.dart` (`pickerItems`).
- Tests: `test/e1_identify_test.dart`.

## Context

A1 phone test (one Edge 60 Fusion, GPU): identify first token 17.7-22.3 s of a 23-27 s request, question text
first token 2-4 s. The owner found the wait too long, and Gemma sometimes misnames small objects (a battery as
a can, film roll or paper). In the tester build Gemma loaded on the first request (cold 41-50 s), so the first
scan also paid for the load.

## Decision

1. Identify speed. The photo sent to Gemma is capped at 512 px on the long side (`identifyMaxSide`, JPEG q85);
   the History photo stays the full crop. The identify prompt is shorter and no longer lists "kaleng aluminium".
   The resize runs inside `_executeSend`, after the single-flight slot is claimed (decision 0003), so a caller is
   never delayed by it; an undecodable photo is sent unchanged. The log gains `[gemma] photo A B -> C B in N ms`
   and `queryMs=` (the time `addQueryChunk` takes, which separates image preparation from the first token).
   Not changed: `maxOutputTokens` (400, set once per chat, the JSON reply is about 40 tokens and ends at its
   own stop token) and the `material` and `category` keys (category is the B3 safety hint; both feed the bank match).
2. "Bukan ini?". A chip next to "Terdeteksi" opens a list of the 13 bank objects (`QuestionBank.pickerItems`, main
   synonym plus the bin of its detector class). Offered from the moment the object is named (hazard card, mismatch
   card, loading, first question) until the first question is answered. Picking restarts the quiz for that item
   through `_startSession`, so a B3 pick shows the hazard confirmation card, hazard keywords still beat the hint,
   the in-flight Gemma request is cancelled, and `_historyPhotoBytes`/`_cropBytes` are untouched, so History keeps
   the photo. The correction is logged (`[scan] item corrected "a" -> "b"`). The bank list is the only choice
   on purpose: a free-text name would have no questions.
3. Background load. `warmUp(scanScreen: true)` is called when the phone scan screen opens. In the tester build it
   loads only if the model file exists, Gemma is not blocked (hot, killed) and nothing is loaded or loading;
   `ensureReady` joins an in-flight load, so a scan during the load waits for it and does not start a second one.
   No file: nothing happens and "Model belum ada" still comes from the scan. No preload at app launch. Non-tester
   builds behave as before.

## Consequences

- Phone effect of 1 is unmeasured. The crop is already small (22-30 KB), so the cap may change little; if
  `photo A -> B` shows A = B and identify ms does not move, the time is the vision encoder itself and the next
  lever is the encoder's own token budget or a smaller model, not the photo. Compare `identify ms=`, `queryMs=`
  and `first token` between the A1 and E1 builds.
- A wrongly named B3 item stays a hazard risk only until the user taps "Bukan ini?"; nothing is auto-corrected.
- Picking an item without a bank object is not possible (13 bank objects only).
