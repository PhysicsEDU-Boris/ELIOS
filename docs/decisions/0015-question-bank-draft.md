# 0015: A module-grounded question bank, drafted for owner review (M3.3)

- Status: Proposed (draft; the owner reviews every item)
- Date: 2026-10-17
- Milestone: M3 step 3 (follows 0013 schema, 0014 chunks)
- Files: `assets/quiz/question_bank_draft.json` (not in pubspec, not wired into the quiz),
  `scripts/validate_bank.py`, `scripts/test_validate_bank.py`,
  `docs/quiz-review/question_bank_review.md`

## Context

Generated questions (0013) are not grounded: Gemma writes from its own knowledge. The owner
wants questions, answer keys and explanations that come only from the course module, with a
page reference, reviewed before any student sees them.

## Decision

- 7 pools from the label map: organik, paper_family (Paper + Paperboard + Cardboard),
  plastic, glass, metal, tetra_pak, e_waste_b3. Human_Hand has none. Each pool has 6 multiple
  choice (2 Mudah, 2 Sedang, 2 Sulit) and 2 essays, so 56 items.
- Multiple choice uses the 0013 shape (`correct` + `wrong[3]`), plus `explanation`,
  `sourceChunk`, `pdfPage` and `quote`. The quote is a verbatim sentence or list item from the
  chunk, at most 40 words, and proves the key. Essays have 2-4 `rubricPoints`, each with its own
  chunk, page and verbatim quote. Every item has `status: "draft"`.
- Text comes only from chunk text. Wrong options contradict the module, not just common sense.
  There are no all/none-of-the-above options.
- Paper family follows the module wording (biodegradable, usually sorted into recyclable
  anorganik). Tetra Pak items carry `sourceQuality: company_sourced` and use no percentages.
- Skipped until the PDF is fixed (M3.2 results):
  - composting steps and maturing time (3.2, 3.5, 3.qa, 8.4);
  - decomposition times (1.5);
  - 7.3;
  - 6.6 numbers;
  - table rows;
  - robot and app questions.
- `scripts/validate_bank.py` enforces these rules:
  - quotes are verbatim and pages lie inside the chunk;
  - mc has 1 correct and 3 distinct wrong options, none equal to the correct one;
  - explanations are 1-2 sentences;
  - no banned chunks or keywords;
  - counts per pool and difficulty;
  - no near-duplicates in a pool (word overlap below 0.6);
  - no copy of a module `T:` question (overlap below 0.8);
  - pools cover exactly the waste labels.

## Consequences

- Nothing changes for students until the owner accepts items and a later task wires the bank
  in (planned: accepted items replace or seed generated questions per pool and difficulty).
- Table rows cannot be checked automatically. I avoided them by hand: every quote is prose or a
  list item. The owner's review is the check.
- The keyword rules are a safety net, not proof: a skipped topic phrased in new words would
  pass. The owner's review covers that too.

## Out of scope

Wiring into the quiz; English versions; questions on the skipped topics; items for Human_Hand.
