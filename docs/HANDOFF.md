# Handoff

Branch `feat/g1c-stopped-camera` (base `780fa37`, origin/feature/live-scan).

## Done (G1c STOPPED Camera Preservation)

- `control_layout.dart`: camera maintains minimum width >= 240 px and identical dimensions with and without STOPPED.
- Calculated `isShort` from window/screen height so STOPPED banner does not flip layout mode.
- Removed vertical flex squeezing on camera inside desktop column; banner height is absorbed by controls and scroll.
- Layout tests verify camera size equality and width >= 240 px across all 7 resolutions plus 800x630/800x520. Break-check verified old layout fails.
- Tests: `flutter analyze` 0 issues; `flutter test` clean (except 2 known stale splash failures in widget_test.dart); `check-secrets.sh` clean.

## R1 (0023), L1

- App uses `SimulatedRobot`; firmware still has no R1 link response. M4 screens remain.
- Fake supports IK + 60 deg/s PICK / MOVE_TO_BIN / DROP, carried-item visibility, base motion and
  servo movement; scenarios cover full sort, B3, hand pause, unreachable and position nudge.
- Fake suite command: `ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q` from `tools/fake_maixcam`.

## M2d robot test (not run; fake scenarios cover most)

- Quizzed peel in view: bottle locks 15 s after quiz closes; second bottle waits 2 s; check JSONL.

## Quiz state

- Bank default (0018/0019); detector class picks questions (0025); owner reviewing banks.
- Next quiz task: accepted filter, kardus Q1, level chip vs Mudah first, generic Q5.

## Next tasks

1. R1-fw (0023 link + 0026 watchdog/STOP), after G2a.
2. Arm bring-up over ESP32 UART after ESP32/Uno sketches; use physical e-stop near people.
3. Camera calibration (0022), M4 overlay, R2 sort modes, CI, M5 Android, M6 ByteTrack, M7 release.

## Known open

- Image identify first token 7–9 s; chat interrupting scan waits up to 8 s (0003).
- Two stale splash tests (`test/widget_test.dart`); yellow cup scores 39–56%.
