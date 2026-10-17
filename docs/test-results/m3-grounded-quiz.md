# M3.4: grounded quiz, real model A/B

- Date: 2026-10-17, macOS, gemma-4-E2B-it (LiteRT-LM, GPU, image=true). Test:
  `integration_test/grounded_quiz_test.dart` (passed every run). Same 10 objects
  (passed as `ScannedWaste`, no images), 3 questions each: q1 MC Mudah, q2 essay Sedang,
  q3 MC Sulit; each question avoids the earlier ones. B also skips chunks cited earlier.
- A = current ungrounded prompt (random angle, 1024 context). B = retrieved module passages
  (2048 context). "Total" = one `generateQuestion` call including its retry.
- B v1 used the first grounded prompt. Gemma sometimes put the object line ("Benda yang
  discan...") in `chunk`. v2 lists the allowed ids in the prompt and accepts "[4.2]" too.

## A vs B

| | A | B v1 (450 w, first prompt) | B v2 (450 w, final prompt) | B v3 (300 w, final prompt) |
|---|---|---|---|---|
| Parsed (question shown, not fallback) | 30/30 | 22/30 | 22/30 | 20/30 |
| Quote verbatim in a sent passage | 0/30 | 22/30 | 22/30 | 20/30 |
| Question names the object | 30/30 | 22/30 | 22/30 | 20/30 |
| Fallback after 2 attempts | 0/30 | 8/30 | 8/30 | 10/30 |
| Needed a 2nd attempt | 3/30 | 12/30 | 12/30 | 14/30 |
| Prompt words p50 | 97 (max 171) | 540 (max 587) | 544 (max 590) | 400 (max 445) |
| First token p50 (ms) | 333 | 937 | 1003 | 1269 |
| Total p50 (ms) | 3827 | 5575 | 6807 | 8725 |
| Total p95 (ms) | 7719 | 12577 | 13689 | 19330 |
| **Question 1 total p50 (ms)** (gate 6000) | 3701 | 4783 | 8069 | 9705 |
| Near-duplicate pairs within an item | 0 | 2 | 1 | 0 |

A has no quote, so "verbatim" is 0 by design. A's questions name the object 30/30, but nothing
ties their answer keys to the module.

## Latency gate: question 1 p50 must stay under 6 s

**Not met at 450 words:** v1 4.8 s, but v2 8069 ms. Retries
cause it, not prompt length:
- an accepted first attempt takes about 4.5-5.3 s;
- half the question-1 calls needed a second attempt;
- first token rises from about 0.3 s (A) to about 1.0 s (B), because of the longer prompt.
- A smaller budget did not help: at 300 words (B v3) question 1 p50 was 9705 ms with 20/30 parsed. First token was even higher, so run-to-run variance on this Mac is large and n=10 per question slot is small.

## Why B fell back (v2)

- quote not verbatim in the passages: Ponsel q1, Laptop q3, Baterai q3, Gelas plastik q1, Gelas plastik q2, Toples kaca q3, Kardus q3
- unparseable: Kardus q1

Rejections across all attempts (v1): quote not verbatim 10, unparseable 8, wrong chunk id 4,
object not named 1. The non-verbatim quotes are near-copies with 1-2 words changed
("anorganik" for "anorganis", "dalam" for "di", "Jangan buang" for "Jangan membuang"), or
4-word table fragments ("Kertas dan karton 11,09%", under the 5-word minimum).

## Fixtures with thin passages

- Ponsel, Laptop: the module's e-waste detail is in table chunks (2.6, 2.7, 2.9, 4.7), which are
  never sent. Passages are 1.4, 5.2, 2.8, 2.summary, 2.qa and 2.1 (general B3).
- Kotak susu: only 4.6 is eligible, so all 3 questions reuse it (allowed when nothing else is left).
- Toples kaca: 4.5 and 6.8 only (the module says little about glass).
## Validator fixes made after the runs (not re-measured)

- 4 of B v2's 22 accepted questions cited a different sent chunk than the one their quote comes
  from. The validator now credits the real source chunk and page. That changes only the logged
  trace, not acceptance.
- 3 accepted essays had placeholder rubric points (e.g. `["1", "2"]`). Rubric points now need at
  least 3 words. Those replies would now be retried, so B v2's real parse rate is at most 19/30.

## Proposal (not built; the flag stays off)

The task said to propose a smaller passage budget if the gate failed, but 300 words measured
worse, so a smaller budget alone is not the fix. Second attempts are what is slow. Options,
in the order I would try them, each to be measured with this test:
1. **Snap near-verbatim quotes:** when a quote matches one module sentence except for 1-2 words,
   replace it with that sentence and accept. That covers most "not verbatim" rejections (10 of
   23 in v1), and the stored quote stays exact module text.
2. **Lower temperature for grounded prompts only** (0.9 -> 0.4): copying text is a low-entropy
   task. Decision 0013 kept 0.9 for open questions.
3. **Then** retry 300 words, with more runs (n=10 per slot is noisy: v1 vs v2 differ by 3.3 s
   at the same settings).
