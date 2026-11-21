## App onboarding tour — `feat/app-onboarding-tour` (0238, 21 Nov, from `feature/live-scan` 806dcdf)
`lib/widgets/tour/app_tour.dart` (engine: `AppTour.run`, `TourTip`, `TourKeys`; Control guide reuses its card + painter) and `main_tour.dart` (Welcome, `mainTourParts`). Shell shows Welcome once (`tour_welcome_seen`) and runs parts on `AppTour.request`. 20 screens wrapped in `TourTip` (`tour_tip_<id>`); scan pages skip robot screens (STOP). Profile ▸ App tour section. Quiz countdown waits while a tour shows. Figma ELIOS 3 · 18 (933:31650).
Tests: `test/widgets/app_tour_test.dart` (5, break-checked), profile test scrolls; full suite + analyze + secret scan clean. Phone APK `def11ee` installed; main tour checked end to end (see build notes). Open: review/ELIOS AI tour and Learn/History inner tours not seen on the phone.
## README refresh — `docs/readme-refresh` (19 Nov, from `feature/live-scan`)
README rewritten: status table, architecture, Gemini identify + quiz flow, robot controls, run steps. Images exported from Figma (L4 scan, R3 control, architecture 79:135, bin check 860:28986) into `docs/readme/`. Docs only; no code or tests changed.
## Arm fader throttle — `feat/arm-fader-throttle` (0236, 19 Nov, from `feat/maixcam2-arm-bridge` 2d37825)
`FaderThrottle` (`lib/services/robot/fader_throttle.dart`): gripper / Height / Reach drags run `_armMove` at most every 100 ms, last value always; STOP and dispose drop a waiting one. BASIS, HOME, PICK, RELEASE unchanged.
Tests: `test/robot/fader_throttle_test.dart` (break-checked), full suite 2095 passed / 20 skipped, analyze + secret scan clean. Phone APK `7c4a97c` vs the MaixCAM2 over USB: 7 ARM_POSE per drag (was 54–66), end pose unchanged. Not pushed, no PR.
## MaixCAM2 arm bridge — `feat/maixcam2-arm-bridge` (0235, 19 Nov, from `feat/arm-kinematics` c7de9d1)
Firmware m2c-arm-v1 (package v1.2.0, deployed on the MaixCAM2 19 Nov, ping sha `17c1204f…` verified; ESP32 not wired yet; old floor-guides v1.1.0 backed up in `/root/backup/` on the board, floor guides off): `arm_bridge.py` streams 20 Hz `F0..F5,CC` to the ESP32 (UART2 9600, stream mode, trims/invert from CONFIG), answers 0023 (STATUS, ARM_POSE, HOME planned, MOVE_TO_BIN/DROP from bin_sequences.json, HOLD, STOP, CONFIG; PICK not_implemented), re-checks limits + tank, DROP guard (bin tag within 2 s), watchdog hold, ESP32 BOOT → HOME first. App syncs its arm pose from `servo` in replies.
Tests: firmware 50 passed (20 new, guards break-checked); app full suite + analyze + secret scan clean. Phone APK `e575271` installed 19 Nov and checked against the board over USB: arm keys send ARM_POSE, board replies motion_done + servo, HOME and STOP pose sync work. Open: UART2 to the ESP32 not tested (no STAT yet), fader ARM_POSE not throttled (~60 per drag), floor guides (0192) need a new tag id before merging, wheels later.
## Arm keys planned in the app — `feat/arm-kinematics` (0234, 19 Nov, from `feat/bin-tag-check` 4960378)
`arm_kinematics.dart` (port of sim hil/kinematics.py, golden-tested vs sim 75ab797) + `arm_pose.dart`: BASIS, Height/Reach (IK, pitch kept), gripper, PICK (75 + offset), RELEASE (180), HOME (planned path) all planned with joint limits + tank; sent as `ARM_POSE` path, refused moves show a snackbar. Unknown pose after STOP / R1 sort → only firmware HOME. Fake MaixCAM2 plays ARM_POSE.
Tests: full suite 2092 passed / 20 skipped, analyze + secret scan clean; new arm tests break-checked; fake 37 passed (same 2 old failures). Open: real MaixCAM2 ignores ARM_POSE (firmware task next, with the DROP guard), fader sends not throttled, not run on phone or robot.
## Bin tag check — `feat/bin-tag-check` (0233, 19 Nov, from `feat/advanced-settings` 1f16d8f)
Bin AprilTags id 2 anorganik / 3 organik / 4 B3 (`Bin.tagId`, print `docs/print/apriltags-bins-id2-id3-id4-A4.pdf`, 30 mm like id 0). R1 arm step 3 = look for `robotBin`'s tag after MOVE_TO_BIN: right 0.5 s → DROP; wrong / none in 3 s → retry once → end `bin_check_failed`, no DROP, control screen sends HOME. Firmware `TAG_SIZES_MM` + ids 2–4; fake MaixCAM2 `--bin-tag right|wrong|none`.
Tests: 5 new in `test/r1_orchestrator_test.dart` (4 break-checked), full suite 2076 passed / 20 skipped, analyze + secret scan clean; fake 33 passed, same 2 old failures. State points: `firmware/maixcam2/bin_sequences.json` (owner's Left-Tank-Throw = B3: Poses 1–4 to the state point, 5–7 drop + home; tank-safe in the sim); fake plays it via the sim planner. Open: Organik / Anorganik sequences, real firmware MOVE_TO_BIN, not run on the robot.
## Advanced settings — `feat/advanced-settings` (0232, 19 Nov, = `feat/joystick-control` + merge of `feat/sim-sync`)
Carries #141 (control v2), #142 (joysticks 0231) and #143 (sim sync 0230). New: `robot_settings.dart` (model + SharedPreferences `robot_settings_v1`, PIN), `advanced_settings_screen.dart` (6 sections, L2 v3 style), Advanced button beside Guide (phone only), joystick config live from settings, Save sends `CONFIG` (firmware ignores it until R1-fw). Safety and connection read only; no ESP32 STAT yet.
Tests: `test/robot/robot_settings_test.dart`, `test/screens/advanced_settings_test.dart`, phone Advanced button test; break-checked.
## Joystick control — `feat/joystick-control` (0231, 19 Nov, from `feat/control-v2-layout` 9c2fe3c)
`JoystickController` (`lib/services/robot/joystick_*.dart`, 20 Hz): deadzone + quadratic curve + slew + mixer for the drive stick (fader = top PWM), rate-integrated base for BASIS (≤ 40 deg/s, ±90). Locks from MotionGate / R1 each tick; HOME resets base angle to 90. `DriveJoystick.onStick`, `BaseJoystick.onStick`; `driveCommand` removed. Departures from the spec in 0231 (no stick timeout, no serial builder).
Tests: `test/robot/joystick_{math,controller}_test.dart` (26, break-checked), widget joystick tests rewritten for ramps. Assumed: app `motor` PWM = fader %, base servo 90 = centre. Not run on the phone or robot; constants untuned.
## Control v2 — `feat/control-v2-layout` (0229, 19 Nov, from `feature/live-scan`)
Phone landscape Control (`phone_control.dart`): LOCK / SCAN / power keycaps under the speed fader, no gear chips or card status chips, STOP/GO at the end of the camera row, BASIS left-right joystick (`BaseJoystick`, `baseJoystickDir`) turning `servo base` 2° / 100 ms while held (`control_screen.dart` `_baseTimer`). Figma 885:31003 (light), 892:31074 (dark).
Tests: full suite 2018 passed / 20 skipped, analyze + secret scan clean; new BASIS test break-checked. Phone 19 Nov: APK `47287be` installed (data kept), checked with the fake MaixCAM2 in light and dark (layout connected + offline, BASIS turns both ways and stops): `docs/test-results/0229-control-v2/`. Saved robot address is now 127.0.0.1 (see build notes). Not checked on the real robot.
## Robot arm sync — `feat/sim-sync` (0230, 19 Nov, from `feature/live-scan` 5443174)
Synced with robotic_hand_sim `75ab797` (local `~/GITHUB/ELIO/robotic_hand_sim` fast-forwarded to it). Changed: `r1_constants.dart` (`armTimeout` 30 s, `waitCap` 180 s for the 30 deg/s Arm A/B), `simulated_robot.dart` comment, fake MaixCAM2 per-joint speeds + limits from the sim's `hil/config.py`. Docs: 0230 (new protocol, joint table, gripper map, MaixCAM2 UART2/UART1 wiring), 0027 / 0023 amended.
Assumed, not seen on the robot: which ESP32 firmware is flashed, base at home at power-up, the MaixCAM2 pin names. Not built: MaixCAM2 bridge (R1-fw), wheel watchdog, 115200 baud.
Tests: `test/robot/arm_timing_test.dart` (armTimeout test break-checked; waitCap test also passes the old values). Fake: 37 passed; `test_frame_fields_match_main_py_old_firmware` and `test_labels_match_main_py_and_app` failed before this change too. Not run on the robot.

## PDF export redesign — `feat/pdf-export-redesign` (0228, 17 Nov, branched from `feat/essay-explanation-review`; phase 3 of 3)
Layout in `lib/services/quiz_pdf_design.dart` (part of `quiz_pdf_service.dart`): cover, page per question, single question + notes page, light/dark from ELIOS tokens. `QuestionPdfOptions.dark`; `PdfThemeChoice` in both sheets; `showQuizReportSheet` for full reports. Static Google Sans Flex weights in `assets/fonts/pdf/`. Photo re-encoded (640 px, JPEG 80). Renders: `docs/test-results/0228-pdf-export/`.
Tests: `test/pdf_export_design_test.dart` (22, break-checked); older PDF tests read `QuizPdfService.debugTexts`. Not checked on phone or robot; not printed on paper.

## Essay answer review — `feat/essay-explanation-review` (0227, 17 Nov, branched from `fix/quiz-review-bugs`; phase 2 of 3)
`EssayReview` (`lib/widgets/quiz/essay_review.dart`) is the essay review in the live quiz, History and the old overlay, built from History widgets (`HistoryResultHero.essayScore`, `HistoryQuestionPanel.essay`, `HistoryMission` texts, new `HistoryEssayScore`). Grading reply now carries per-criterion hints, why, key idea, tips; saved in existing `QuizExplanation` fields. `quizRevealCue` for correct / partial / wrong. Renders: `docs/test-results/0227-essay-review/`.
Tests: `test/essay_review_test.dart` (22, break-checked). Not checked on phone or robot; no real grading reply with the new fields seen yet. Mac build still blocked by signing (no profile for `com.boris.elio`).

## Quiz review bugs — `fix/quiz-review-bugs` (0226, 17 Nov, from `feature/live-scan` 953e25d; phase 1 of 3, phases 2 and 3 stack on it)
Mute: saved `AppPreferences.quizMuted` → `QuizTtsService.muted` + `ElioSound.quizMuted` (`quizFeedback` in quiz / explanation pages); review speaker button toggles it. Coach: `AiQuizService.messageLang` picks the reply language from the message. Back: `PopScope` + "Leave the quiz?" sheet in `ScanQuizPages`. Explanation: loading block until the final text, one request per key + epoch + 25 s timeout, fallback to the question's own text, Retry state, voice reads the shown text, skipped questions keep an explanation. Root cause in the decision doc.
Tests: `test/quiz_review_bugs_test.dart` (14, each break-checked). Not checked on the phone or robot. iOS swipe-back is blocked during a quiz but opens no sheet.

## Final QA, 16 Nov 2026 — `chore/final-qa` (merge of the 7 task branches on `feat/control-l4-figma`)
PRs: #127 language switch (0218) · #128 essay switch (0219) · #129 XP icons (0220) · #130 profile header (0221) → base `feature/live-scan`; #131 hazard page (0222) · #132 essay explanation (0223) · #133 bin check (0224) → stacked on #126. Decision docs hold the details.
Merged build: `flutter analyze` clean, full suite 1949 passed / 20 skipped, secret scan clean. Phone: Edge 60 Fusion, debug APK `d5ef58a` (LIVE_SCAN / TESTER_BUILD / DARK_MODE_OPTION), `adb install -r`, data kept, left light / English on Home (16 scans, 445 XP as found).

| Check | Widget tests | Phone | Robot |
|---|---|---|---|
| Language switch EN↔ID on changed screens | pass | pass: Profile, Learn (Today's Guide follows), History, scan detail | not run |
| History reopen after a language switch | pass (network held) | pass: content in under 1 s, both ways (records had both languages cached; the "Translating…" note was not seen live) | not run |
| Dark mode on changed screens | pass | pass: Profile header + settings | not run |
| Essay switch on / off | pass | row shown below Difficulty (EN, ID, dark); quiz with it off not played | not run |
| XP icons | pass | pass: Home hero, History rows | not run |
| Profile header + entry animation | pass | pass (stills); animation not watched | not run |
| Hazard B3 scan | pass | not run (needs a hazardous item) | not run |
| Essay explanation | pass | not run (needs a real essay quiz) | not run |
| Bin check right + wrong, STOP | pass | n/a (robot only) | not run |
| Sound + haptics on new taps | cues asserted in tests | not heard / felt | not run |
