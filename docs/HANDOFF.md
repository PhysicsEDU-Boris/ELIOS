# Handoff

Branch `feat/g2c-home-status-fixes` (base `58fd087`, origin/feature/live-scan). PR #48 (open, by Gemini).

## Acceptance follow-up (2026-10-28)

- Fixed simulator-reproduced STATUS bypass: `at_home:true` cannot confirm HOME or reset sliders; only matching HOME `motion_done` does. EE telemetry and false/null clearing remain active.
- Break-check: mismatched-completion and invalidation regressions failed before the fix and pass after it. Focused HOME/store tests: 15 passed; analyze and secret scan clean.
- Full suite: 477 passed, only the 2 documented stale splash tests failed.
- No physical robot used. UI simulator acceptance was not rerun after this fix; fresh history/trophy quit/relaunch persistence remains unverified. Keep PR #48 unmerged pending owner acceptance.

## Done (G2c Mac Test Fixes & Protocol Hardening)

- Strict HOME completion: reset reach/height/gripper to 90/90/0 and set `atHome: true` only on matching `motion_done`; handle errors, STOP, disconnects, and timeout without claiming home completion.
- Kept `ee_mm` current: send STATUS after `motion_done` and debounced 300 ms after drag; clear coordinates on null `ee_mm` or disconnect.
- Serialized `ScanRecordStore` concurrent operations (load, add, clear, save) to guarantee disk persistence under rapid writes.
- Scan History: display "Tersimpan lokal" sync indicator and real question count on difficulty pills.
- Decisions [0027](decisions/0027-arm-serial-protocol.md), [0028](decisions/0028-trophy-rules-and-scan-history.md), [0030](decisions/0030-quiz-result-card-and-history-save.md).

## R1 (0023), L1

- App uses `SimulatedRobot`; firmware still has no R1 link response. M4 screens remain.
- Fake supports IK + 60 deg/s PICK / MOVE_TO_BIN / DROP, carried-item visibility, base motion and
  servo movement; scenarios cover full sort, B3, hand pause, unreachable and position nudge.
- Fake suite: `ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q` from `tools/fake_maixcam`.

## Robot / Mac test

- Drag height to 171, hold HOME 1s -> sliders reset only on `motion_done`; drag to 160 moves arm DOWN from neutral.
- Trigger STOP, disconnect, or timeout during HOME -> pending home canceled, sliders and `atHome` remain unconfirmed.
- End-effector XYZ readout updates live ~300 ms after reach/height release, on `motion_done`, and clears when null.
- Complete a quiz / rapid saves -> restart app -> scan history retains all records and trophies count.

## Quiz state

- Bank default (0018/0019); detector class picks questions (0025); owner reviewing banks.

## Next tasks

1. R1-fw (0023 link + 0026 watchdog/STOP), after G2a/G2b/G2c.
2. Arm bring-up over ESP32 UART after ESP32/Uno sketches; use physical e-stop near people.
3. Camera calibration (0022), M4 overlay, R2 sort modes, CI, M5 Android, M6 ByteTrack, M7 release.

## Known open / Tests

- 477 unit/widget tests pass; 2 known stale splash tests (`test/widget_test.dart`) fail.
- Image identify first token 7–9 s; chat interrupting scan waits up to 8 s (0003).
