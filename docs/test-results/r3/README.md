# R3 Control for phones: test results (2 Nov 2026)

Decision [0174](../../decisions/0174-r3-control-phone.md). Branch `feat/r3-control-phone` on `feat/r2-control-gamified` (50d0a38).

## Widget tests

`test/widgets/phone_control_test.dart` (80) and `test/screens/control_phone_test.dart` (4). 915x412, 800x360 and 932x430, light and dark:
driving, offline, waiting, stopped (GO), skeleton, quiz question, review right / wrong / essay, Guide steps 1, 3 and 5.
Each: no overflow, STOP on screen (GO in its place when stopped with a link; under the Guide a hit area over STOP).
Gate rules: GO sends no motion command (break-checked: with `gate.motor(50,50)` added to GO the test fails with `motor 50,50`, then restored);
STOP → GO → STOP; offline sends zero commands; the joystick still takes touches while STOPPED and the gate drops them;
no Resume / Lanjutkan, no ELIOS badge beside the title, no Quiz button without a quiz, nothing on top of the video.
Real ControlScreen: phone size picks R3, tablet keeps R2, the Guide opens once and saves `r3_phone_guide_shown`.
PNGs of the 915x412 states: `widget/`.

## Phone (Motorola Edge 60 Fusion, USB, debug APK c884b32+, tester flags, `SCAN_RECORDS_FILE=scan_records_r3test.json`)

- **Data safety.** Before: `scan_records.json` backed up outside the repo (27 records, sha256 53b5e2ca…). Home showed 0 scans / 0 trophies
  (the empty test store) before anything was touched. After: owner file byte-identical, mtime unchanged (2 Nov 02:12), `scans/` unchanged;
  no record was saved (no quiz session was finished), so the test file was never created. The signed-in owner account was used (no guest login exists);
  "Save as default config" was switched off for the 127.0.0.1 address. No Scan lagi.
- **Robot.** `fake_maixcam` (scenario one_Plastic) over `adb reverse tcp:8765`; no real robot. Reverse removed, fake stopped afterwards.
- **Build hygiene.** The 2.59 GB Gemma model was moved to a parking folder beside the repo and back for each of 3 builds (no copy); the APK is the only build output and stays in `build/`.
- Logs: `logs/fake_command_log.txt` (per action, first session; later steps in `logs/fake_second_session.txt`). Shots: `phone/`, pairs with the Figma frame: `side-by-side/`.

| Check | Result | Evidence |
|---|---|---|
| Joystick forward / left / let go | pass: motor 75,75 → 0,0; left (gear 100) -100,100 → 0,0 | fake log |
| Gear 100, speed, gripper fader, PICK UP, RELEASE | pass: no command for gear; servo gripper 59 / 100 / 0 | fake log |
| HOME: tap = nothing, hold 1.3 s = HOME | pass | fake log |
| Height / reach faders | pass: servo height / reach 90 → 158 | fake log |
| STOP → GO → STOP; commands while STOPPED | pass: STOP + motor 0,0; joystick sends only 0,0; PICK UP nothing; GO sends nothing; after GO motor works | fake log, `light_stopped` |
| STOP while the Guide is open | pass: STOP logged | fake log |
| Offline (no fake): controls press, zero commands | pass: only `motion_blocked … no_link` events, 0 sends | `light_offline`, `dark_offline` |
| Power off, then Connect | pass: disconnect_ack; Connect reconnects, STOP + motor 0,0 first, STOPPED + GO until GO | `dark_offline`, `dark_reconnected_still_stopped` |
| Quiz: opens, minimise, Quiz button reopens | pass | `light_quiz_question`, `light_quiz_minimised`, `dark_quiz_minimised` |
| Answer right and wrong, review, coach chat (Gemma), Listen, Next question | pass (TTS started; Gemma hint reply shown; Next → question 2/3) | `light_quiz_explanation`, `dark_quiz_wrong`, `dark_quiz_chat_reply` |
| Essay review | partly: input is the old popup; grading did not return in 2 min on the phone so "Checking your answer…" showed. Rows are covered by the widget test only | `light_quiz_essay_explanation*` |
| Guide: first run (opens by itself offline), Next ×4, Let's go, from the Guide button, dark | pass (first build never opened it: it checked orientation; fixed, see below) | `light_first_run_guide1_offline`, `light_guide2..5`, `dark_guide1` |
| Drawer, History, theme switch | pass (History is the existing screen and shows the empty test store) | `light_drawer`, `dark_drawer` (account row masked), `dark_history` |
| Light and dark | pass | `light_*`, `dark_*` |
| Space / Esc | not tested: no keyboard attached |  |
| Skeleton on the phone | not captured: it lasts under 1.5 s; widget PNGs only | `widget/skeleton_*` |

## Bugs found on the phone, fixed
1. First-run Guide never opened: it checked "landscape" while the screen was still portrait. Now the short side.
2. Video box stayed 4:3 and narrow: now fills the card. Top-bar pill and connection chip were cut ("Conn…"): they now get the free width.
3. Coach chat showed a duplicate greeting and hid new replies below the fold: greeting only when empty, list shows the newest.
4. Essay review showed a red "Score 0 / 10" while grading: now a neutral "Checking your answer…".
5. Guide step 3 card overlapped the action bar (card height was guessed): anchored by its bottom edge. Checked in the widget PNG, not re-run on the phone.

## Visual differences from Figma
| Difference | Fix or reason |
|---|---|
| Painted card art (road, clouds, sun, hills) not drawn; no SVGs exported to `assets/illustrations/control/phone/` | Not done in this task. Flat theme fills instead. Follow-up |
| Joystick is the R2 widget (flat rim, 4 chevrons), no 3D bezel or glow | Reused so the commands and dead zone stay identical. Follow-up with the Figma SVG |
| Text is the theme's font (Inter), not Google Sans Flex | The app theme does not bundle Google Sans Flex; not changed here |
| ELIOS AI badge is a ring + Material leaf icon | Figma badge SVG not exported |
| Quiz "Back" minimises | No state exists to return to the question; old Back was disabled |
| Wrong answer: picked bin red only if the option names a bin (bank options such as "PVC" do not) | Options are free text; no bin is known otherwise |
| Question text and answers are Indonesian bank content | Content, not UI |
| Identifying / hazard / mismatch / essay input / final result still use the older Indonesian popup | No R3 Figma frames for them |
| 800 dp: mission segments hidden, long chip text can shorten | Fit at the smallest tested width |
| Avatar shows the account photo, not "B"; History is the old light screen | Real data / existing screen |
| Offline robot art is the app's existing art, not the sleeping robot | Existing asset reused |
