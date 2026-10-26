# Handoff

Branch `feat/g2c-home-status-fixes` (base `58fd087`, origin/feature/live-scan). PR pending (by Gemini).

## Done (G2c Mac Test Fixes)

- On HOME (ack and motion_done), reset reach and height values to 90 and gripper to 0 in UI and MotionGate.
- Kept `ee_mm` current by sending STATUS on `motion_done` and debounced 300 ms after reach/height drag.
- Fixed `ScanRecordStore` data loss across rebuild/restart with preload on startup and safe load guard.
- Scan History: display "Tersimpan lokal" sync indicator and real question count on difficulty pills.
- Decisions [0027](decisions/0027-arm-serial-protocol.md), [0028](decisions/0028-trophy-rules-and-scan-history.md), [0030](decisions/0030-quiz-result-card-and-history-save.md).

## R1 (0023), L1

- App uses `SimulatedRobot`; firmware still has no R1 link response. M4 screens remain.
- Fake supports IK + 60 deg/s PICK / MOVE_TO_BIN / DROP, carried-item visibility, base motion and
  servo movement; scenarios cover full sort, B3, hand pause, unreachable and position nudge.
- Fake suite: `ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q` from `tools/fake_maixcam`.

## Robot / Mac test

- Drag height to 171, hold HOME 1s -> after home, drag to 160 moves arm DOWN from neutral (not up).
- End-effector XYZ readout updates live ~300 ms after reach/height slider release and on motion_done.
- Complete a quiz -> restart app -> scan history retains record and trophies count.

## Quiz state

- Bank default (0018/0019); detector class picks questions (0025); owner reviewing banks.

## Next tasks

1. R1-fw (0023 link + 0026 watchdog/STOP), after G2a/G2b/G2c.
2. Arm bring-up over ESP32 UART after ESP32/Uno sketches; use physical e-stop near people.
3. Camera calibration (0022), M4 overlay, R2 sort modes, CI, M5 Android, M6 ByteTrack, M7 release.

## Known open / Tests

- 470 unit/widget tests pass; 2 known stale splash tests (`test/widget_test.dart`) fail.
- Image identify first token 7–9 s; chat interrupting scan waits up to 8 s (0003).
