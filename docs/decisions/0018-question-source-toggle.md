# 0018: Debug switch between the question bank and Gemma (M3.6)

- Status: Accepted; the "not saved" part is replaced by 0145 (2 Nov 2026)
- Date: 2026-10-18
- Builds on: 0017 (bank by default, Gemma path kept behind `GEMMA_QUESTIONS`).
- Code:
  - `lib/providers/app_preferences_provider.dart` (`QuestionSource`, `effectiveQuestionSource`);
  - `lib/providers/waste_quiz_provider.dart` (`_sessionSource`, `_logQuestion`);
  - `lib/widgets/question_source_switch.dart`;
  - `lib/Screens/control_screen.dart` (under the LIVE_SCAN debug overlay);
  - `lib/widgets/waste_quiz_popup.dart` (`questionSourceHeader`).
- Tests: `test/question_source_test.dart`, `test/object_bank_test.dart`.

## Why a runtime switch

The owner wants to compare the pre-written bank and Gemma-generated questions on the robot
with the same objects. Rebuilding with a different `--dart-define` for each comparison costs
minutes and loses the running state. So a two-option control ("Bank soal" / "Gemma") sits
under the LIVE_SCAN debug overlay.
- It is saved in the existing `AppPreferences` (`shared_preferences`), so no new dependency.
- `GEMMA_QUESTIONS` is only its initial value; the default is still the bank.
- Debug builds only: release builds never show it and always resolve to the bank, whatever is
  stored.

The source is captured when a session starts, so a change applies from the next scan. A bank
session never starts Gemma question work, even if the switch moves during it. A prefetch from
an earlier Gemma session is cut off by the session counter (0011) and never shown.

## Why no silent bank fallback in Gemma mode

The point of Gemma mode is to see what Gemma produces and how long it takes. If a failed,
timed-out or rejected generation quietly became a bank question, the comparison would mix
the two sources and look better than Gemma really is. So Gemma mode falls back only to the
fixed fallback questions, as before 0017, with the header "SOAL CADANGAN (AI ON-DEVICE BELUM
SIAP)".

## Header and log

- Bank question: "SOAL DARI MODUL · BANK SOAL".
- Gemma question: "SOAL GEMMA". It never claims to come from the module.
- Fixed fallback: "SOAL UMUM (BENDA BELUM ADA DI BANK SOAL)" in bank mode. In Gemma mode the
  fallback keeps "SOAL CADANGAN (AI ON-DEVICE BELUM SIAP)", because there the object may well
  be in the bank and that wording would be false.
- Every question shown logs one line, plus a `question_source` JSONL event in debug:
  `[WasteQuiz] question_source question= source= item= object= pool= fromScanMs= loadMs= fallback=`.
  `pool` is `gemma` in Gemma mode. `fromScanMs` runs from the resolved scan, so for B3 or
  mismatch scans it includes the confirmation card. No question text is logged.

## Amendment 24 Oct (R1): the switch is no longer saved

In the 24 Oct fake-MaixCAM2 test, a debug build started on "Gemma".

- The build default is the bank: the robot build passes no `GEMMA_QUESTIONS`, and
  `defaultQuestionSource` is the bank.
- So the value came from `shared_preferences`, saved when the switch was moved in an earlier
  debug session.

**The question source is now kept for the running session only:**

- `AppPreferences.toMap` no longer writes it, and `fromMap` ignores a value saved by an older
  build.
- Every launch, and every fresh install, starts on the build default (the bank).
- Release builds still always use the bank.
- Comparing the two sources still works within one session, which is what the switch is for.

Test: `test/question_source_test.dart`, "a launch after a debug session left the switch on Gemma
starts on the bank".
