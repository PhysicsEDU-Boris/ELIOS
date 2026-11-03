# 0013: Multiple-choice schema: one correct answer plus wrong distractors (M3.1)

- Status: Accepted
- Date: 2026-10-16
- Milestone: M3 step 1 (plan 1.3; follows finding 1 of decision 0005)
- Code: `lib/services/gemma_quiz_service.dart` (`_tryGenerateQuestion` prompt,
  `parseQuestion`; test hooks `temperature`, `angleOverride`, `onQuestionReply`)
- Tests: `test/quiz_parse_test.dart`; real model
  `integration_test/quiz_temperature_test.dart`
- Evidence: [m3-quiz-parse](../test-results/m3-quiz-parse.md)

## Context

The prompt asked for "4 pilihan" once in prose, with a 4-slot example array.
The parser accepted exactly 4 non-empty options and `correctIndex` 0-3. Gemma
often wrote 5 options anyway (12 of 14 rejections in 0005, 2 of 3 M0.4 probes on
16 Oct, 3 of 5 rejections in the baseline run here). These were well-formed
5-option questions with a valid index, the common A-E exam layout. So it was
model behaviour the prompt didn't hold: not prompt ambiguity, and not a parser
bug. The count lived only in the prose and in an index that had to agree with it.

## Decision

Ask for `{"question", "correct": "...", "wrong": ["...", "...", "..."], "explanation"}`
("tepat 1 jawaban benar dan tepat 3 pengecoh"). The parser:

- requires `correct` to be one non-empty string (a list or a missing field is
  rejected);
- rejects the reply if any distractor equals the answer (case/punctuation
  normalized), since that gives two correct options;
- skips empty and repeated distractors, needs at least 3 left, and uses the first 3;
- shuffles the 4 options and sets `correctIndex` from the position of `correct`.

The answer key is the `correct` field itself, so dropping a 4th distractor can
never move the key. That is the risk 0005 warned about for cutting an
`options` list. The `GeneratedQuestion` shape (4 options + `correctIndex`) is
unchanged, so the UI and providers are untouched. Essay prompts and parsing are
unchanged (they never failed).

## Temperature (recommendation only, not changed)

Same 5 prompts, 5 runs at 0.9 / 0.4 / 0.3. After the fix: 5/6, 5/5, 5/6
attempts parsed and 15/15 questions; 0 count failures at any temperature.
Before the fix the worst value was 0.4 (4/8). No temperature is clearly better
at n=5, and 0.4/0.3 were about 1-2 s slower per attempt in the after run.
**Keep 0.9.** Revisit only if the remaining JSON-syntax failures (2 of 17:
trailing comma, unclosed array) matter. The question bank (plan 2.1) removes
most of this risk anyway.

## Out of scope

- Repairing invalid JSON (trailing commas etc.): not a count problem. The
  2-attempt retry already absorbed both cases here.
- A 20-run-per-value test (0005's suggestion). This one used 5, as the task asked.
