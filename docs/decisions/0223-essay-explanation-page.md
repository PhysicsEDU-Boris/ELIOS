# 0223 — Essay explanation page

Date: 16 November 2026. Branch `feat/essay-explanation-page`, **stacked on
`feat/control-l4-figma` (PR #126, 0217)**. Figma `ELIOS 3`: portrait 853:28675 (dark
855:28861), landscape 856:28871 (dark 856:29021); MCQ page 662:26004 / 662:26256.

## Where

The essay review the app shows is the essay branch of `_ScanReviewPage` in
`lib/widgets/quiz/quiz_scan_pages.dart` (phone and robot). `QuizEssayExplanationOverlay` in
`quiz_explanation_overlay.dart` is no longer used by the app (tests only) and is unchanged.

## What changed

- Header: "Answer review" and "Question N of M · Essay · <item>", close and listen buttons.
- Verdict leaf: Right tone and "GOOD THINKING" when the score passes (6 or more), Wrong tone
  and "NOT QUITE" otherwise; the score as the title, "Checked by ELIOS AI", and the XP pill.
- "YOUR ANSWER" card with the learner's text in quotes; leaf-shaped green "THE CORRECT ANSWER"
  card with the model answer (`referenceAnswer`, hidden when none was saved).
- "Why it works this way" + squiggle + the grader's feedback and its "For full marks" tip,
  then the ELIOS AI coach entry and Next question.
- Landscape: left column scrolls (verdict, correct answer, your answer, why); right column:
  coach entry and Next question. The coach opens as the full page, as in portrait.
- Landscape header (essay and MCQ): Figma's ellipse 960×540 at (−300, −470) plus its bubble,
  clipped to the header, so the curve stays above the content.
- Cards stagger in (`ElioPopIn`); reduce motion gives a short fade.
- New strings (EN + ID): `qzGoodThinking`, `qzTheCorrectAnswer`, `qzCheckedByAi`.

## Not done, on purpose

- **"Key points in your answer" is hidden.** The essay grader returns four rubric scores,
  feedback and one improvement tip, not key points, and nothing is invented. The tick pop +
  tick sound belongs to that section, so it is not built either. The rubric rows (real data)
  stay, inside the "Your answer" card. To show key points the grader's JSON contract needs a
  `key_points` list (text + found); that is a prompt and parser change with its own tests.
- "Why it works this way" shows the grader's feedback, not a separate long explanation: essays
  have none today.
- The header keeps the close (X) button of the MCQ page instead of Figma's back chevron: on
  the robot it minimises the quiz, it does not go back.
- Dark frames and the MCQ frames were not re-fetched; landscape was read from its screenshot.

## Tests

`test/screens/scan_quiz_pages_test.dart`: landscape layout and order, portrait order and
strings (EN/ID × light/dark), failing score tone, no model answer, MCQ landscape guard, plus
the existing no-overflow matrix for `essay-review`. Break-check: 7 essay tests fail on the old
page. Renders: `docs/test-results/0223-essay-explanation/`.
