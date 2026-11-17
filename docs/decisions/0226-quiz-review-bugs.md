# 0226 — Quiz review bugs: mute, coach language, back confirm, stable explanation

Date: 17 November 2026. Branch `fix/quiz-review-bugs` (from `feature/live-scan` 953e25d).
Phase 1 of 3; `feat/essay-explanation-review` and `feat/pdf-export-redesign` stack on it.

## 1. Mute button

The speaker button of the answer review only replayed the explanation; nothing could
silence the quiz. It is now a mute toggle.

- One saved flag, `AppPreferences.quizMuted` (same `app_preferences_v1` storage as the other
  preferences). `applySoundPrefs` pushes it to `QuizTtsService.muted` and
  `ElioSound.quizMuted`.
- `QuizTtsService.speak` does nothing while muted; turning mute on calls `stop()` at once.
- Quiz and explanation pages play their sounds through `quizFeedback` (haptic always, sound
  unless muted). Sounds elsewhere in the app are not affected; Profile → Sound effects stays
  the app-wide switch.
- `WasteQuizUiState.voiceOn` now mirrors the saved flag, so the robot control "Voice" switch
  and the old overlay's Voice chip are the same setting.
- Unmuting reads the explanation on screen (the only way left to replay it from the header).

## 2. Coach language

`AiQuizService.discuss` asked for the app language. It now uses
`AiQuizService.messageLang(message, appLang)`: counts the message's words in the existing
EN/ID word lists; more matches wins; none or a tie is the app language ("ok", "?", emoji,
numbers). The prompt states the reply language explicitly and the reply is read from that
side of the JSON. No package, no network call.

## 3. Back during a quiz

`ScanQuizPages` wraps its pages in `PopScope(canPop: false)` while a question or its review
is showing. A system back, and the phone page's own close button, open a bottom sheet
("Leave the quiz?" / "Keep going" / "Leave"). Only Leave calls `dismiss()`. The sheet is its
own route, so the quiz state in `wasteQuizProvider` is not touched while it is open.

- iOS / macOS swipe-back: `canPop: false` disables the gesture, so it cannot throw the quiz
  away; it does not open the sheet (Flutter gives no callback for a blocked swipe).
- Robot control: the close button still minimises (the quiz is kept); a system back asks.

## 4. The first question's explanation kept changing

Root cause (line numbers at 953e25d):

1. **Shown, then replaced.** `lib/widgets/quiz/quiz_scan_pages.dart:2521-2524` showed the
   question's own explanation (`q.explanation`) as soon as the review opened, because
   `currentExplanation` is still null while the AI explanation loads; the loading block at
   `:2907` only showed when that text was empty. When `loadExplanation` finished, the text was
   swapped for the AI's `summary`, and the page below it moved.
2. **Question 1 only: replaced by nothing.** `lib/services/quiz_explanation_service.dart:40-42`
   returns the bank explanation when the single AI slot is busy. On question 1 the slot is
   busy prefetching questions 2..N, so an AI-written question (no bank id) got
   `QuizExplanation.unavailable`, and the review dropped the explanation it had been showing.
   `:73` stamps `generatedAt` on that result too, so
   `lib/providers/waste_quiz_provider.dart:1480` treated it as final and never asked again.
3. **Voice read the first version.** `waste_quiz_provider.dart:1214-1219` spoke
   "verdict + q.explanation" at answer time (`_appendAiReply`, `:1655`), before the AI text
   existed.
4. Not the cause: no double request (the service already shares an in-flight request per
   key, `ai_quiz_service.dart:669`), no streaming, no regeneration on a language change.

Decision:

- The review shows a loading block until `explanationLoading` is false, then the final text.
  The text block is at least as tall as the loading block.
- `loadExplanation` requests once per (session, question index, language) and carries an
  epoch; a reply from an older request is dropped. A 25 s timeout ends a hung request.
- AI failed, timed out or busy: the question's own explanation is used (reviewed bank text,
  else the generated question's text) and saved. Neither: "Explanation not available yet"
  with Retry (`retryExplanation`, which bypasses the saved result).
- The voice-over is started by `loadExplanation` with the text it just put on screen. A
  changed text (language switch) stops the old speech.
- Skipped questions now save their explanation too (they saved none, which is where the
  essay "Penjelasan tidak tersimpan" in History / PDF came from).

## Not done

- The answer chat's first message still carries the question's own explanation text.
- After a language switch the new text is not read automatically (Phase 2).
- Not checked on the phone or robot yet; see HANDOFF.

## Tests

`test/quiz_review_bugs_test.dart` (14 tests). Break-check: each fix was reverted in turn and
the matching test failed; results in the PR description.
