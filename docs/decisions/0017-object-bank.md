# 0017: Pre-written, object-specific questions; Gemma identifies only (M3.5)

- Status: Proposed (draft bank; the owner reviews every item)
- Date: 2026-10-18
- Milestone: M3 step 5. Owner decision 17 Oct, after #24 (grounded generation was on-object
  but often wrong or garbled, 8.1 s p50 for question 1 against the 6 s gate, and the laptop ran
  hot): Android v1 uses a pre-written, owner-reviewed bank only. #24 stays a draft and
  `GROUNDED_QUIZ` stays off.
- Builds on: 0013 (mc schema), 0014 (chunks), 0015 (label-pool bank, PR #23; this branch is
  cut from it).
- Code:
  - `assets/quiz/object_bank_draft.json`;
  - `lib/services/question_bank.dart`;
  - `lib/providers/waste_quiz_provider.dart` (`_fromBank`, flags, fallbacks, early finish);
  - `lib/widgets/waste_quiz_popup.dart` (source label);
  - `scripts/extract_module.py` (table rows);
  - `scripts/validate_bank.py`.
- Tests: `test/object_bank_test.dart`; `scripts/test_validate_bank.py`;
  `scripts/test_extract_module.py`.
- Review: [object_bank_review.md](../quiz-review/object_bank_review.md)

## Decision

1. **Table rows.** The extractor rebuilds tables 1.6, 2.6, 2.7, 2.9 and 4.7 as one sentence
   per row (`rows`, next to the unchanged `text`), using pypdf's positional visitor:
   - consecutive runs at one x form a cell;
   - returning to the first column starts a row;
   - every cell of a row must share its first-line y, or the extractor stops.

   A test checks each cell against its PDF page. Quotes may come from the text or from a row
   sentence.
2. **Object bank.** 13 objects:
   - ponsel, laptop, perangkat elektronik (from the logs: "perangkat elektronik/scanner");
   - baterai, lampu TL/CFL;
   - botol plastik, gelas plastik, toples/botol kaca, kaleng aluminium;
   - kardus, kertas, kulit pisang/sisa makanan, kotak susu.

   Each has `synonyms`, optional `notIf` vetoes, a label/pool, 4 MC (gelas plastik: 3) spread
   over Mudah/Sedang/Sulit, and 1 essay with rubric points. Items keep the 0015 schema plus
   `object`.
3. **Matching** (`QuestionBank.matchObject`):
   - Names are normalized: lower case, `/ _ - . ,` become spaces.
   - The longest synonym found in the item name wins. A synonym found only by adding a material
     word ("botol" + "plastik") scores lower.
   - `notIf` words veto an object ("kaleng aerosol" is not an aluminium can; "botol" with
     "plastik/kaca" is ambiguous, so no object).
   - A B3 object never serves a non-B3 scan, or the reverse, so the questions never contradict
     the hazard card.
4. **Serving** (default on, no flag needed):
   - the object's questions in file order;
   - then the label pool's from `question_bank_draft.json`, found by detector class, else bin,
     else item/material words;
   - then the fixed fallbacks (3 MC, 2 essay).

   Nothing repeats within a session. When everything is used, the session ends early instead.
   The hazard and mismatch gates are unchanged (they run before the first question).
5. **Gemma.**
   - No question request is sent by default. The old generation path, with prefetch, stays
     behind `--dart-define=GEMMA_QUESTIONS=true` for a later opt-in.
   - Gemma still identifies the object, and still grades essays when they are on.
   - A fake-Gemma test fails on any question prompt.
6. **Essays.** Off by default: `--dart-define=ESSAY_QUESTIONS=true` brings back the MC/essay
   alternation. When off, every question index is MC and the session length is unchanged.
7. **Validator.**
   - It rejects "kutipan", "passage" and "modul kuliah" in question text, and options that mix
     units.
   - It reports, without failing, a wrong option that its cited chunk states word for word.
   - It checks per-object counts and difficulty spread, near-duplicates within an object, and
     synonyms shared by two objects.
   - The rules also apply to the label bank, where two items mixed units (plastic-mc-05,
     metal-mc-05). They are fixed here.
8. **UI wording.** The question header says "SOAL DARI MODUL · BANK SOAL" for bank items, and
   "SOAL UMUM (BENDA BELUM ADA DI BANK SOAL)" for a fallback in bank mode, instead of claiming
   Gemma wrote the question or that the AI is not ready.

## Consequences

- Questions are instant and deterministic. Their quality is whatever the owner accepts in the
  review sheet; until then everything is `status: "draft"`, as in 0015.
- Objects not in the bank get pool questions, which are about the material, not the object.
- An object with no bank entry and no pool gets at most 3 MC (fixed fallbacks).

## Out of scope

- Aki, kaleng aerosol and other B3 objects not seen in the logs.
- English text.
- Removing the Gemma question code.
- Filtering accepted/rejected items at runtime. The owner's review result has no field yet:
  add `status: accepted` and filter on it once the review is done.
