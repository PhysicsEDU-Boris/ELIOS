# 0016: Object-specific quiz questions grounded in retrieved module passages (M3.4)

- Status: Proposed, not shipped: the latency gate failed (see Result). Behind
  `--dart-define=GROUNDED_QUIZ=true`, default off, until the gate passes and the owner approves
  the sample review.
- Date: 2026-10-17
- Milestone: M3 step 4. Follows 0011 (prefetch), 0013 (schema) and 0014 (chunks). Numbered
  0016 because 0015 is taken by the open question-bank PR #23.
- Code:
  - `lib/services/module_retriever.dart` (new);
  - `lib/services/gemma_quiz_service.dart` (`_tryGroundedQuestion`, `groundedPrompt`,
    `parseGroundedQuestion`, `mentionsObject`, `reviewEssay`, `QuestionGrounding`, context size);
  - `lib/providers/waste_quiz_provider.dart` (`_usedChunkIds`, `fallbackQuestions`, essay grading).
- Tests: `test/grounded_quiz_test.dart`; real model `integration_test/grounded_quiz_test.dart`.
- Evidence: [m3-grounded-quiz](../test-results/m3-grounded-quiz.md),
  [owner sample review](../quiz-review/grounded_sample_review.md)

## Context

Owner decision (17 Oct): the quiz is not a fixed bank. Each question must be about the
scanned object. Until now Gemma wrote from its own knowledge on a random "angle", so nothing
tied an answer key to the course module.

## Decision

1. **Retriever (no model, deterministic).** For each question it picks 2-3 chunks from
   `module_chunks.json`:
   - It works out the module class from the detector label, else from item and material words
     (multi-word objects first: "kotak susu" before "karton"), else from the bin.
   - Eligible chunks are the class's `label_to_chunks` set plus any chunk naming the object.
     The object is the item, a synonym (ponsel/hp/handphone/telepon genggam, baterai/aki,
     botol/gelas, …) or a class word. Material words only boost.
   - It never sends:
     - `table`, `lkpd_key` or `sources` chunks;
     - the `excludedChunkIds` list, with reasons: 3.2, 3.5, 3.summary, 3.qa, 8.4 (composting
       steps and time), 1.5 and 1.qa (decomposition times), 6.6 (superscripts), 2.10 and 7.x
       (robot/app);
     - Bab 2 chunks, unless the object is B3. The CFL steps there mention "toples kaca" and
       "kertas karton".
   - The category-definition chunk is always sent last:
     - 1.3 for organic, paper, cardboard and drink cartons;
     - 1.4 for plastic, glass and metal;
     - 2.1 for B3. 1.6 is a table chunk, so 2.1's prose definition replaces it.
   - At most 2 topic chunks are sent, about 450 words in all (`maxWords`, configurable). The definition is cut at a
     sentence end to fit, and the cut stays a verbatim prefix.
   - Question k skips chunks cited by earlier questions in the session, unless nothing else is
     left.
2. **Prompt.**
   - It gives the object (item, material, category), the passages with their `[chunk id]`, and
     the rule: the question is about this object, answerable from the passages, and uses no
     outside knowledge.
   - Difficulty is phrased so the model stays inside the passages.
   - The 0013 schema is kept, plus `quote` and `chunk`. Essays add `rubric`.
3. **Validation.** `parseGroundedQuestion` accepts a reply only when:
   - the quote is at least 5 words and a verbatim (whitespace-normalized) substring of a sent
     passage;
   - the chunk id was sent;
   - the question names the object (item, synonym, or material/label word);
   - an essay has a rubric, each point at least 3 words (placeholders like "1" were seen on the
     real model).

   A quote cited under the wrong sent id is credited to the chunk it actually comes from, so the
   logged page is right.

   Otherwise it retries (the existing 2 attempts), then falls back. The reason is kept in
   `lastQuestionFailure` and logged.
4. **Fallback.** PR #23's bank is not merged, so the existing fallback is used. It now has 3 MC
   and 2 essay variants, and a session never shows the same one twice. This fixes the 0011
   leftover and applies with the flag off too.
5. **UI is unchanged.** `GeneratedQuestion` gains an optional `grounding` (chunk, quote, page,
   sent ids, passage, rubric) for logs and diagnostics. The popup does not read it.
6. **Essay grading.** `reviewEssay` receives the passage and rubric and is told to grade only
   against them.
7. **Context size.** About 450 words of passage plus instructions comes to roughly 1,100 prompt
   tokens. The old 1024-token context window also has to hold up to 400 output tokens, so the
   model loads with `maxTokens: 2048` only when the flag is on.
8. **Prefetch (0011).** The notifier keeps `_usedChunkIds` next to `_askedQuestions`. It is
   filled in generation order, and prefetch is sequential, so question k sees the chunks of
   questions 1..k-1. It is cleared with every new session.

## Result (real model, see the results doc)

| | A (ungrounded) | B (grounded, 450 words) |
|---|---|---|
| Question shown (not fallback) | 30/30 | 22/30 (v1 and v2) |
| Quote verbatim / names the object | 0/30 / 30/30 | 22/30 / 22/30 |
| Question 1 total p50 | 3.7 s | 4.8 s (v1), **8.1 s (v2)** |

**The 6 s gate failed in the run with the final prompt, so this does not ship.** The flag stays off.
Retries cause the latency (12 of 30 questions needed a 2nd attempt, mostly for near-verbatim
quotes), not prompt size: 300 words was not faster (9.7 s, 20/30). The results doc proposes
next steps (snap near-verbatim quotes to the module sentence; lower temperature for grounded
prompts), each to be measured with the same test.

## Consequences

- Flag off: no change, except the fallback variants (item 4).
- Flag on: question quality depends on the passages. Objects whose module content lives mainly
  in tables (e-waste: 2.6, 2.7, 2.9 and 4.7 are table chunks) get thinner passages. See the
  results doc.
- The owner reviews the B sample before the flag is turned on.

## Out of scope

Using PR #23's bank as the fallback (when it merges); table-row reconstruction; passing the
detector class into `ScannedWaste` (retrieval infers it today).
