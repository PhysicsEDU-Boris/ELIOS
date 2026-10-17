# M3.1: multiple-choice parse, before and after decision 0013

- Date: 2026-10-16, macOS, gemma-4-E2B-it (LiteRT-LM, GPU backend, image=true)
- Test: `integration_test/quiz_temperature_test.dart`, 1 test, passed both runs
- Prompt: `kardus` (bahan kertas karton), `QuizDifficulty.hard`, multiple choice,
  5 fixed angles (run i = angle i at every temperature), no avoid list
- **Before**: base b5499d2 (`options` x4 + `correctIndex`), with only the test
  hooks added, run from a throwaway worktree. **After**: this branch
  (`correct` + `wrong` x3).
- One "run" = one `generateQuestion` call (up to 2 attempts). Duration = one
  attempt, request to reply.

## Summary

| | Before 0.9 | Before 0.4 | Before 0.3 | After 0.9 | After 0.4 | After 0.3 |
|---|---|---|---|---|---|---|
| Attempts parsed | 5/6 | 4/8 | 5/5 | 5/6 | 5/5 | 5/6 |
| Questions shown (not fallback) | 5/5 | 4/5 | 5/5 | 5/5 | 5/5 | 5/5 |
| Rejected: wrong option count | 1 (5 opts) | 2 (5 opts) | 0 | 0 | 0 | 0 |
| Rejected: invalid JSON | 0 | 2 | 0 | 1 | 0 | 1 |
| Attempt duration, range | 3.2-4.9 s | 3.3-3.9 s | 4.6-5.7 s | 4.1-5.6 s | 5.5-8.4 s | 6.0-7.3 s |

Totals: before **14/19 attempts (74%)**, 14/15 questions; after **15/17
attempts (88%)**, 15/15 questions. After the fix every parsed reply had exactly
3 distractors (0 with more), one non-empty `correct`, no empty field and no
duplicate option. In both runs every JSON-valid reply had one valid key.

## Failure detail

- Before, 5 options (3): the model wrote 5 options with a valid `correctIndex`.
  The parser rejected them (correct per decision 0005).
- Before, invalid JSON (2): a stray `)` after an option; options split into
  several arrays (`"], ["`).
- After, invalid JSON (2): a trailing comma after the 3rd distractor (`",\n],`);
  the `wrong` array not closed before `"explanation"`. Neither is about count.

## Earlier baseline (decision 0005)

Across 12 M0 runs: 14 of 47 attempts (30%) rejected, 12 of them 5 options.
Over every M0-era log in `elios-m0-logs/` (overlapping runs): 48 rejected replies,
33 with 5 options, 1 with 6, 11 invalid JSON, 3 other shapes.

## Limits

5 runs per value is too few to rank temperatures (one failure = 17-20%). After
the fix, attempts look ~1-2 s slower than before (longer answer text, plus
`correct` restated as a sentence); not checked beyond these 15 runs.
