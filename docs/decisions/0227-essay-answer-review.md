# 0227 — Essay answer review, with motion, haptics and sound on the explanation pages

Date: 17 November 2026. Branch `feat/essay-explanation-review`, branched from
`fix/quiz-review-bugs` (0226, PR #138). Phase 2 of 3; merge after #138.
Figma: file J2jSbARJSyJCStNFeWkWDj, page "ELIOS 3", section "16 · Essay answer review"
(869:29309): light 869:29312 / 869:29718 / 869:30073, dark 871:29851 / 871:29958 / 871:30066.

## Decision

One widget, `EssayReview` (`lib/widgets/quiz/essay_review.dart`), is the essay review
everywhere: the live quiz review (`_ScanReviewPage`), History's `QuestionExplanationScreen`,
and the old `QuizEssayExplanationOverlay`. It is built from the existing History widgets; no
copies were made. Widgets that needed a new state got it:

- `HistoryResultHero`: `essayScore` (0-4 "Belum tepat" wrong variant + sad robot, 5-9 "Hampir
  tepat!" + thinking robot, 10 "Sempurna!" + excited robot) and `animate`.
- `HistoryQuestionPanel`: `essay` ("PERTANYAAN · ESAI").
- `HistoryMission`: optional title, subtitle and finish line ("Tips skor penuh").
- New `HistoryEssayScore`: the score card (icon tile, verdict, "x / 10", XP pill, total bar,
  rubric rows with segment bars, score colour and AI hint, and the AI note).

Colours are tokens only: red `error` at 0, amber `secondaryText` for partial, green `primary`
for full; empty segments are `borderMedium` and the empty bar `surfaceRaised`, so both stay
visible in dark mode.

## Data

The grading request (`AiQuizService.reviewEssay`) now also asks for `accuracyHint`,
`keyTermsHint`, `completenessHint`, `clarityHint`, `why`, `keyIdea` and `tips` (3 steps).
`EssayGrade.parse` reads them as optional: a missing or malformed field is empty and the
grade itself is kept. They are stored in the existing `QuizExplanation` fields
(`RubricRow.comment`, `correctAnswerReason`, `keyIdea`, `steps`), so they are saved in the
scan record with no format change, and old records open as before.

A section with no data is hidden: no rubric rows, no hint line, no feedback / why / key idea
/ tips card. An ungraded essay shows "awaiting grading" and no score card. A skipped essay
shows "Kamu melewati soal ini".

## Motion, haptics, sound

- Entrance: hero first, then each card fades and rises 10 px, 40 ms apart (`ElioPopIn`).
  The total bar and rubric segments fill and the score counts up (700 ms); the XP counts up;
  the robot does one 6 px bounce (`ElioJump`).
- Reduce motion: everything is at its final value on the first frame.
- No replay: the review is one non-lazy column (History's page moved from `ListView` to a
  scroll view), so scrolling back does not rebuild a card; entrance keys are fixed per
  section, so a rebuild or language switch does not restart them.
- Cue, once per reveal (`quizRevealCue`): correct / full marks = chime + success haptic,
  partial = pop + light, wrong = knock + light. The sound respects the quiz mute (0226); the
  haptic follows the platform. Live essays cue when the grade arrives; History cues as the
  page lands. Live multiple choice keeps its existing cue at the answer tap.

## Differences from Figma (intentional)

- The live review keeps the green curved header (it carries the mute toggle and, on the
  robot, STOP) instead of the plain History top bar with the XP pill.
- The live review keeps the "Ask ELIOS AI coach" entry below the cards; Figma has none.
- Existing strings are reused: "Yuk pelajari alasannya" (Figma "Ayo…") and "IDE UTAMA"
  (Figma "IDE KUNCI").
- The score card's icon is the Material help icon used by the question card, not the Figma
  quiz icon.
- The live multiple-choice review keeps its 0216 layout; only its entrance rise changed.

## Not done

- Golden image comparison: the tests assert content and layout; the PNGs in
  `docs/test-results/0227-essay-review/` are for the eye.
- Not checked on a phone or the robot. A real grading reply with the new fields has not been
  seen yet (the tests use the reply shape the prompt asks for).

## Tests

`test/essay_review_test.dart` (22): 0/10, 6/10, 10/10 in light and dark, EN and ID; 360 dp
at text scale 1.3 with long text; skipped answer; hidden sections; count-up, reduce motion,
no replay; parser, saved fields; cues and mute. Break-check results are in the PR.
