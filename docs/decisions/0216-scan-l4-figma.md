# 0216 — Scan flows in the Figma L4 style, full-screen Scan & quiz pages, motion everywhere

Date: 12 November 2026. Branch `feat/scan-l4-figma` (from `feature/live-scan` c10d02e). Owner
request: make every scan screen match the newest Figma (`06 · Scan`, `13 · Micro-interactions`
cards 21–30, `15 · Scan & quiz landscape + full-page explanation`), with motion, sound and
haptics on every part, quiz questions full-screen like the identified view, light/dark, EN/ID.

## What changed

- **Scan & quiz (phone)**: the quiz popup over the camera is replaced by full-screen pages in
  `lib/widgets/quiz/quiz_scan_pages.dart` (`ScanQuizPages`, same provider calls as the popup).
  - Scan result (629:90773, landscape 659:25791): polaroid drops in (−8° → 3°, spring/pop), the
    bin buddy of the item's waste type pops from behind it, name and bin chip rise, the quiz
    ticket slides up. The quiz waits for **Start quiz**; **Retake** returns to the camera.
  - Question (629:90816, landscape 659:25857): progress dashes, m:ss timer chip (pulses in the
    last 10 s, ticks in the last 3 s), leaf question card with the tilted photo, four coloured
    answers. Right: check badge pops, the others fade. Wrong: the pick shakes with an error
    outline, the right one pulses. The feedback shows for 0.9 s before the review opens.
  - Answer review (662:26004, landscape 662:26256): curved green header, verdict leaf with the
    robot buddy and points, "Why it works this way", bin tiles, coach entry, Next question bar.
    The ELIOS AI coach opens as a full page (the existing chat inside the new header).
  - Quiz complete and "Scan did not work" are full pages too (no Figma frame; same style).
  - Camera: flash button, shutter press (0.85), AI-quiz chip with the ELIOS AI badge.
- **Select vehicle** (629:90849): lit stage with pedestal, leaf slots, art popping out of the
  selected slot. Locked drone: slot shakes, badge wiggles, "Coming soon" toast, S5 + H-warning.
  Select: ring draws, art and robot hop, pedestal bounces, S1 + H-select. Use ELIOS: robot hops,
  then the page opens (S6 + H-medium).
- **ELIOS setup**: wire "charges" to the next node when a step is done, the live node pulses
  while searching/connecting, a failed node shakes and the wire flickers (S5 + H-error); orbit
  bubbles pop in and float, the status bubble hops on a link change, glow breathes; quiz source
  switch in the Figma look (white pill, database / ELIOS AI icons that react), collapsing when
  the quiz is off; Video and Quiz sections enter with the page.
- **Robot Wi-Fi QR sheet**: invalid input shakes the form (S5 + H-warning); showing the QR and
  the password eye give feedback.
- **Scan to contribute**: REC chip slides in and its dot blinks, record button morphs, checking
  shows the leaf spinner over a skeleton, the result sheet has a handle, medal swing, 12-leaf
  confetti, XP count-up (S9 + H-celebrate); "try again" nudges the sheet, grey medal,
  highlighted hint (S5 + H-warning).
- Bold weights: titles on these screens used `copyWith(fontWeight:)`, which leaves the variable
  font regular; they now use `homeWeight`.

## Not 1:1 with Figma (kept on purpose or left open)

- Hazard notice, item mismatch and essay questions still show the popup's own views inside the
  page (no full-page design).
- The coach page reuses the existing chat bubbles, not the 662:26171 bubble style.
- Bin tiles say Yes / No only (the explanation data has no per-bin reason text).
- Contribute keeps the pick-a-bin flow: no live item box or bin-label guide (the app has no
  live detector on the phone).
- No gallery button and no live "object found" chip on the camera (no image picker dependency,
  no live detector).
- Select vehicle and ELIOS setup are pushed pages without the bottom nav.
- The vehicle stage shows the flat robot (it morphs from the hub); the 3D model with
  drag-to-rotate stays on ELIOS setup. The stage robot leans with a horizontal drag instead.
- ELIOS setup keeps the ELIOS AI status card and has no battery bubble (the robot reports none).
- The yellow answer keeps dark text for contrast (Figma: white on #D89E00, about 2.3:1).
- The photo does not morph from the camera into the polaroid; the polaroid drops in.

## Tests

- `test/screens/scan_quiz_pages_test.dart`: result → Start quiz → question, Retake, answer
  feedback then review and coach, failed scan, finished quiz; no overflow in portrait, small,
  landscape × light/dark × EN/ID (`SCAN_RENDER=<dir>` writes PNGs). Break-checked: the
  "page starts at the top" check fails on the centred layout (76 px) and passes with the fix.
- `test/screens/select_vehicle_test.dart`: locked drone knock + toast, ELIOS tick, no overflow.
- `test/screens/config_screen_test.dart`: the quiz source switch collapses with the quiz off.
- Contribute has no widget test (needs a fake camera and AI); checked on the phone.

## Phone check (Edge 60 Fusion, 12 Nov)

Debug APK `c050b64` installed in place, dark / English: hub, Select vehicle (locked toast),
ELIOS setup, Wi-Fi QR sheet, contribute ("Not quite" path with the real AI), real Scan & quiz
(laptop and mobile phone identified, hazard notice, Start quiz, wrong answer). The later
commits (answer review, coach and quiz-complete pages) were not installed: the phone was
unplugged. Not checked on the phone: light mode, Bahasa Indonesia, landscape, sounds and
haptics by ear/hand, the approved contribution result.
