# 0174 R3 Control for phones: one STOP/GO button, no ELIOS logo in the top bar, Guide, English quiz popups

Status: Draft (2 Nov 2026). UI only on top of 0173 (R2), 0026 (STOP, MotionGate), 0145 (C1).
Figma J2jSbARJSyJCStNFeWkWDj, page 393:2358 (light and dark frames, component sheet 393:2359).

## Decision
- **Where it applies.** `isPhoneLandscape`: shortest side < 600 dp and landscape. Phones get
  `PhoneControlLayout` (`lib/widgets/control/phone/`); tablets and the Mac keep R2 unchanged.
  `ControlScreen._phoneLayout` passes the same handlers R2 uses, so commands, ranges, the dead zone,
  the 1 s HOME hold and message formats are unchanged.
- **STOP and GO are one round button.** After STOP (with a live link) the same place shows a green
  GO. GO calls the existing `_resumeAfterStop` (`MotionGate.resume`) and sends nothing itself. There
  is no "Resume driving" / "Lanjutkan" button and no stopped banner on phones: the top bar shows the red
  pill "Robot stopped · scanning paused" and the chips say "Stopped". With no link the button stays
  STOP (Figma 397:2604). STOP is never dimmed; it stays reachable under the quiz (its small STOP), the
  Guide (a hit area over the button), the skeleton, offline and waiting. Space and Esc are unchanged.
- **No ELIOS logo or badge next to "Robot Control".** The ELIOS AI badge only appears on the Quiz
  button and in the quiz popup header.
- **Nothing on the video.** The chips (LIVE · fps, Scan quiz, Voice, connection) sit in a row above
  it. No bands, pick zone, reticle, tag, `dist_cm` or floating quiz button on phones.
- **Offline looks and presses normally.** Controls are not dimmed or absorbed; `MotionGate` drops
  every command (no link), so zero are sent. The joystick also still takes touches while STOPPED and
  the gate drops them. Connect and the power button use the existing connect flow.
- **Skeleton** shows until the first connect attempt settles (max 1.5 s); the real STOP is in it.
- **Quiz popups** (`phone_quiz.dart`): question (4 quiz colours, "Read it to me" = `QuizTtsService`
  via `notifier.listen`) and the review for multiple choice (right and wrong) and essay (score banner +
  scoring rows), with the ELIOS AI coach (`sendChatMessage`, Listen chips, suggestions). Phases the
  Figma does not draw (identifying, hazard/mismatch confirm, essay input, final result) stay on the
  older popup. "Back" minimises (the old Back was disabled; there is no way to re-open the question
  after answering). The picked bin is marked red only when the chosen option names a bin.
  `WasteQuizUiState` is unchanged.
- **Guide** (`phone_guide.dart`): 5 steps with a spotlight on the drive pad, STOP, the action bar and
  the Quiz button (centred when there is no quiz). From the Guide button any time. It also opens by
  itself the first time Control opens on a phone; `SharedPreferences` key `r3_phone_guide_shown`
  (per device, set when it opens, so Skip is final). The check uses the short side, not the
  orientation: the screen is still turning landscape on the first frame (found on the phone).
- **Test record store.** `--dart-define=SCAN_RECORDS_FILE=<name>` (default `scan_records.json`) lets a
  test build keep records in another file. Normal builds are unchanged.

## Not done / differences (see docs/test-results/r3/README.md)
Painted card art and the SVG export into `assets/illustrations/control/phone/`, the 3D joystick
bezel and the exact ELIOS AI badge art are not drawn; shapes use flat theme colours.

## Open question
Should GO and the logo removal also apply to the R2 tablet and Mac layout?
