# 0219 — Essay questions on/off in Profile

Date: 16 November 2026. Branch `feat/settings-essay-toggle` (from `feature/live-scan` 86f078e).
Owner request: an Essay switch in settings, below Difficulty.

## Decision

- Profile → Quiz gets an **Essay questions** switch directly below Difficulty (`_SwitchRow`,
  `setEssay` / `setEssaySub`, EN + ID), saved as `AppPreferences.essayQuestions`.
- Off: every question is multiple choice. On: questions alternate multiple choice / essay as
  before. One gate (`WasteQuizNotifier._essays` → `questionTypeFor`) serves ELIOS AI and the
  question bank, phone and robot scans.
- The switch replaces the build flag as the gate. Its **default is the old build flag**
  (`ESSAY_QUESTIONS` define or tester build = on, otherwise off, decision 0017), so no build
  changes behaviour until the student flips it. A normal robot build therefore starts with
  essays **off**.
- The switch is read per question, so a change applies from the next question.

## Tests

`test/essay_toggle_test.dart` (save/load; AI and bank quizzes with the switch off and on) and
`test/screens/profile_screen_test.dart` (row sits between Difficulty and Timer, is saved).
Break-check with the setting ignored: the two "essays on" tests fail; the "off" tests pass on
the old code because off was already the default.
