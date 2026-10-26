# Handoff

- Author: Gemini. Branch `feat/u2-result-card` (PR #43 open), base `origin/feature/live-scan` (`c39831b`).
  Never commit Xcode scheme, `Maixcam.txt`, `docs/module/`.
- Decisions: 0013–0019 quiz/module; [0020](decisions/0020-lock-rearm-rule.md) re-arm,
  [0021](decisions/0021-manual-driving-orchestration.md) orchestration,
  [0022](decisions/0022-detection-protocol-distance-tags.md) protocol,
  [0023](decisions/0023-r1-command-link.md) R1 link,
  [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2,
  [0025](decisions/0025-bank-detector-class.md) bank class,
  [0026](decisions/0026-emergency-stop-motion-gate.md) stop + watchdog,
  [0028](decisions/0028-trophy-rules-and-scan-history.md) trophy rules & scan history,
  [0029](decisions/0029-arm-reach-gripper.md) arm reach + gripper width,
  [0030](decisions/0030-result-card-and-scan-history.md) result card & scan history.

## Done (U2 Result Card & Scan History)

- Result card (`lib/widgets/waste_quiz_popup.dart`): shows item name, category badge, "x of N correct",
  trophies earned (`+$T Piala`), grade & level after scan, buttons "Scan lagi" and "Tutup".
- ScanRecord saving: finished session creates `ScanRecord` with JPEG crop and persists to local store.
- Live scan `waitingForRescan` state: pauses locking until "Scan lagi" without bypassing 0020 re-arm.
- R1 drop gate (`--dart-define=R1=true`): card shows drop notice and disables "Scan lagi" during drop.
- Telemetry: emits `session_result` `{correct, total, trophies}` and `rescan_tapped`.
- Tests: `live_scan_rescan_test.dart` and `result_card_test.dart` (5 viewports, no overflow, STOP reachable).

## R1 (0023), L1

- App is tested on `SimulatedRobot`; today's firmware returns no R1 link response. M4 screens remain.
- L1 fake adds IK + 60 deg/s PICK / MOVE_TO_BIN / DROP, carried-item visibility, motor-driven base
  motion and base/elbow/gripper servo movement. Scenarios cover full sort, B3, hand pause, unreachable
  and position nudge; see `tools/fake_maixcam/README.md`.
- Fake suite: `ROBOTIC_HAND_SIM=~/GITHUB/ELIO/robotic_hand_sim ~/.venvs/fake-maixcam/bin/python -m pytest -q` from `tools/fake_maixcam`; 33 passed.

## M2d robot test (not run; fake scenarios cover most)

- Quizzed peel in view: bottle locks 15 s after quiz closes; second bottle waits 2 s; check JSONL.

## Quiz state

- Bank default (0018/0019); detector class picks questions (0025); owner reviewing banks.
- Next quiz task: accepted filter, kardus Q1, level chip vs Mudah first, generic Q5.

## Next tasks, in order

1. **Next: G2a fake/docs**, then L0b serial protocol decision 0027, then R1-fw (0023 link + 0026 watchdog/STOP).
2. Arm bring-up over ESP32 UART after ESP32/Uno sketches; use physical e-stop near people.
3. Camera calibration (`0022`), M4 overlay, R2 sort modes, CI, M5 Android, M6 ByteTrack, M7 release.

## Known open

- Image identify first token 7–9 s; chat interrupting scan waits up to 8 s (0003).
- Two stale splash tests (`test/widget_test.dart`); yellow cup scores 39–56%.
