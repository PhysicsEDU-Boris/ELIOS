# 0217 — Robot control: full-screen scan pages, essay page, scan-start animation

13 Nov 2026 · branch `feat/control-l4-figma` (stacked on `feat/scan-l4-figma`, PR #125)

## Why

The owner asked for the robot control screen's scan and quiz to match the new Figma frames:
`815:31496` (scan identified, before quiz), `815:31579` (quiz question, full screen),
`821:28687` (essay question, full screen) and section `629:97994` ("09 · Quiz result popups":
answer review + ELIOS AI correct / wrong, essay review, scan history), with a scan-start
animation, sounds, haptics, dark mode, EN/ID, and a keyboard that never covers the UI.

## What changed

- **Control screen** (phone and tablet layouts) shows `ScanQuizPages(robot: true)` instead of
  the `WasteQuizPopup` card. Robot mode: title "Robot scan", "Just now · Robot camera",
  "Scan again" (logs and restarts the live scan), the compact STOP in every page header
  (decision 0026 still holds: the open quiz covers the screen's own STOP), and the close
  button minimises, so the student can keep driving and reopen from the Quiz button. The
  result page keeps the R1 "robot is dropping" notice and does not leave the control screen.
- **Essay question page** (phone and robot): "Your answer" field with word count, Submit
  answer, Skip. Over 150 words: the field shakes, nothing is sent.
- **Essay review**: score as the verdict, the student's answer quoted, rubric rows with one
  dash per point that fill in turn, XP = score.
- **Landscape review**: review on the left (verdict, explanation, bins), the ELIOS AI coach
  chat and Next on the right, as in the Figma frames. Portrait keeps the coach as its own page.
- **Scan-start animation** (robot pages): when the pages open they grow out of a 4:3 camera
  frame in the middle of the screen (420 ms) with a blip and light haptic; every page
  (identified, question, essay, review, result) arrives under a green scan line with
  viewfinder brackets (560 ms). Reduced motion: none of it.
- **Keyboard**: the pages pad themselves above the keyboard whether or not the host screen
  resizes. Essay on a short screen with the keyboard open: one line of the question, the
  field and Submit only; the typed text survives the layout switch. Coach chat on a short
  screen with the keyboard open: messages and the ask field only.

## Not 1:1 with Figma

- Figma was read from the browser (the Figma connector was down all session), so sizes and
  colours come from the existing tokens and from looking, not from measured values.
- "Speak" (voice typing) on the essay field: not built; the app has no speech-to-text.
- "Ask ELIOS AI for a hint" on the essay page: not built; the coach is deliberately silent
  until an answer is given (see `sendChatMessage`).
- Q1 / Q2 / Q3 chips and "Why it goes there" chip in the review header: not built.
- "9 Scan history" frame (landscape history with "Ask ELIOS AI about this scan"): not built.
- "MaixCam 2 component": I found no such component to reuse and could not search Figma for
  it; the animation is drawn in code as a camera viewfinder. The page grows from the screen
  centre, not from the measured position of the camera panel.
- The identified frame has no STOP; the app shows it there too, for safety.
- Hazard notice and item mismatch still use the old popup look inside the page.
- The control screen itself (drive pad, arm, camera panel) is unchanged.

## Tests

`test/screens/scan_quiz_pages_test.dart` (225 tests): robot wording / STOP / minimise /
rescan, essay type-count-submit, over the limit, keyboard open in landscape, small landscape
and portrait (field and Submit above the keyboard, text kept), essay review, coach with the
keyboard in landscape, no overflow for every state × phone/robot × 4 sizes × light/dark ×
EN/ID. Break-checked: the landscape keyboard test fails without the compact layout.
Full suite 1732 passed, 20 skipped; analyze clean; string audit 0.

## Phone check (Edge 60 Fusion, light / Bahasa Indonesia)

Build `5bfc300`, robot not connected: ELIOS setup without the ELIOS AI card and Tester mode;
a phone scan through result, question, review, coach page with the keyboard open, quiz complete.

Build `5bfc300` then `18559f6`, robot connected (watching and scanning only, the robot was
not driven): SCAN on the control screen opens "Scan robot" with the robot camera photo and the
STOP pill; Start quiz; the question arrives under the scan line with brackets; close
minimises to the control screen with the Quiz button and the lock box, the Quiz button
reopens the question; a wrong answer; landscape review with the coach beside it; quiz
complete with Done staying on the control screen. Images: `docs/test-results/0217-control-l4/`.

**Bug found on the device and fixed (`18559f6`):** tapping the coach's ask field in landscape
opened the keyboard and it closed again at once. The page moved the field to another place in
the tree for its keyboard layout, which rebuilt it and dropped focus. The essay field had the
same flaw. Both now keep their state through a global key; the keyboard tests check that the
field is still focused after the keyboard opens (they fail on the old code). Confirmed on the
robot screen: keyboard stays, typed text and the last coach message sit above it.

Seen but not changed:
- Minimising and reopening a question restarts its countdown (the old popup did the same).
- The pages sit inside the control screen's safe area, so in landscape a strip the width of
  the camera cutout stays at the left of the green header.
- Two scans did nothing visible: the AI service answered HTTP 503 ("every Gemini model is
  busy or capped") and the control screen shows no message for that.
- The AI named the same lanyard "Tali lanyard" once and "Kaleng aluminium" once.

Not checked: an essay on any device (no quiz gave one), the STOP pill pressed (it would stop
the robot), "Scan again", the opening grow animation (too fast to capture), sounds (the phone
is on silent, the app skips them), haptics, dark mode and English on the robot pages.
