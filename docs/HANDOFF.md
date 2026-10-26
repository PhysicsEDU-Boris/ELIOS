# Handoff

Branch `feat/g2b-arm-home-control` (base `90e1150`, origin/feature/live-scan). PR open.

## Done (G2b Arm HOME and Height Control)

- `RobotController.home()` sends HOME command; `SimulatedRobot` models 2s travel to J4 home pose `[0.0, -42.5, 90.0]`.
- Parsed `ee_mm` and `at_home` from `STATUS` reply into `RobotState` and Riverpod `robotControlProvider`.
- ARM HEIGHT control wired to `servo part=height` (hand ±Z) via `MotionGate` instead of elbow. Lateral control disabled.
- `HomeButton` with 1-second hold-to-confirm gesture and green progress fill on student screen; instant button in Debug Scan sheet.
- MotionGate routing: HOME blocked while STOPPED (not in `_allowedWhileStopped`), ignored during R1 SORTING, paused on hand in view (`HOLD`).
- Debug overlay: AprilTag chips for IDs 0 and 1 shown with `dist_mm` only when seen; EE xyz readout from `ee_mm`.
- Decision [0027](decisions/0027-arm-serial-protocol.md).

## R1 (0023), L1

- App uses `SimulatedRobot`; firmware still has no R1 link response. M4 screens remain.
- Fake supports IK + 60 deg/s PICK / MOVE_TO_BIN / DROP, carried-item visibility, base motion and
  servo movement; scenarios cover full sort, B3, hand pause, unreachable and position nudge.
- Fake suite command: `ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q` from `tools/fake_maixcam`.

## M2d robot test (not run; fake scenarios cover most)

- Quizzed peel in view: bottle locks 15 s after quiz closes; second bottle waits 2 s; check JSONL.
- Arm HOME & height test: verify hold-1s HOME returns all-zero pose, ARM HEIGHT moves ±Z.

## Quiz state

- Bank default (0018/0019); detector class picks questions (0025); owner reviewing banks.
- Next quiz task: accepted filter, kardus Q1, level chip vs Mudah first, generic Q5.

## Next tasks

1. R1-fw (0023 link + 0026 watchdog/STOP), after G2a/G2b.
2. Arm bring-up over ESP32 UART after ESP32/Uno sketches; use physical e-stop near people.
3. Camera calibration (0022), M4 overlay, R2 sort modes, CI, M5 Android, M6 ByteTrack, M7 release.

## Known open

- Image identify first token 7–9 s; chat interrupting scan waits up to 8 s (0003).
- Two stale splash tests (`test/widget_test.dart`); yellow cup scores 39–56%.
