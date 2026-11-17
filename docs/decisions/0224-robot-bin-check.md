# 0224 — Robot bin check before the quiz

Date: 16 November 2026. Branch `feat/robot-bin-check`, **stacked on `feat/control-l4-figma`
(PR #126, 0217)**. Figma `ELIOS 3`, section "08 · Control": bin check 860:28986, wrong
860:29035, right 861:29181, quiz ticket 860:29118, quiz 860:29164 (dark row not fetched).

## Flow (robot control only)

1. Quiz on the control screen opens a full-screen **bin check**: chip "Bin check · before the
   quiz", "Where will this waste go? Pick the right bin.", three full-width bars (Organik red,
   Anorganik blue, B3 yellow). It is the quiz question page (`_ScanQuestionPage`) with a
   built-in question, so the answer bars, their stagger, right / wrong feedback, the timer and
   STOP are the existing ones. The right bin is the scan's category. Items with no bin
   (residu / unknown) skip the check.
2. After 0.9 s of feedback the identified page shows with a **result ticket** (`_BinTicket`)
   in place of the quiz ticket: picked bin buddy with ✓ or ✗, "Nice sorting! <bin> it is" or
   "Oops! Not the <picked> bin", one sentence why the item belongs in its bin, a green
   "+20 XP" or grey "+0 XP" chip, "Your quiz is next", **Got it**.
3. Got it flips the ticket (fade + flip, instant with reduce motion) to "Your quiz is ready"
   on the same page; Start quiz opens question 1 as before.

Sounds: right = S4 chime + H-success, wrong = S5 knock + H-warning, Got it = S1 tick.

## State and XP

- `WasteQuizUiState.binPick` / `binAcked` live in the quiz provider, so a rebuild or minimise
  keeps the result. `answerBinCheck` takes the first pick only: the 20 XP cannot be earned
  twice. Skip (when allowed) and time-up end the check with no ticket and no XP.
- The XP goes through the existing path: it is added to the scan record's `trophies` when the
  quiz is saved, so History, the level and the end-of-quiz count include it. No new record
  field. **If the quiz is closed before it ends, no record is saved and the 20 XP is lost**,
  like the question XP.
- "Not this?" is hidden once the bin was picked (a correction would restart the check).

## Not asking the bin twice

The built-in fallback quiz's first question ("Ke aliran pengelolaan mana … masuk?") is skipped
after a bin check. **Not handled:** bank or ELIOS AI questions that ask about the bin are not
tagged, so they can still appear; removing them needs a tag in the bank or a line in the AI
prompt.

## Phone

Unchanged. The pages are shared, but the check is switched on for `robot: true` only.

## Not 1:1

- The reason sentence is one l10n string per correct bin with the item name, not AI text.
- Bar labels use the app's answer style (larger than the Figma instance text).
- With the hazard popup of this branch a B3 item goes bin check → result ticket → hazard card;
  with PR #131 the last step is the hazard page.

## Tests

`test/screens/scan_quiz_pages_test.dart` group "robot bin check" (question, STOP, right once +
flip without a route change + Start quiz, wrong EN and ID/dark, skip, phone has none) and the
no-overflow matrix (`bin-right`, `bin-wrong`, `bin-done`); `test/bin_check_xp_test.dart` (the
saved record holds +20 for the right bin only). Break-check: 4 page tests fail with the old
routing, the record test fails without the XP sum. The fallback-question skip has no test.
Renders: `docs/test-results/0224-robot-bin-check/`.
