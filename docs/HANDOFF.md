# Handoff

## In progress

- G2a (`feat/g2a-arm-protocol`, PR #44): protocol decision 0027 and fake HOME/STATUS/reach/height.
  Lateral is disabled in v1 because world-X requires J1 and pans the camera. Measured tags: home
  shows none; inspect `[0,50,-120,90,-45]` shows tags 0 and 1. Fake suite: 39 passed.
- U2 result card / scan history (decision 0030) is merged in #43.
- Never commit Xcode scheme, `Maixcam.txt`, or `docs/module/`.
- Decisions: 0013–0019 quiz/module; [0020](decisions/0020-lock-rearm-rule.md),
  [0021](decisions/0021-manual-driving-orchestration.md),
  [0022](decisions/0022-detection-protocol-distance-tags.md),
  [0023](decisions/0023-r1-command-link.md), [0024](decisions/0024-fake-maixcam-sim.md),
  [0025](decisions/0025-bank-detector-class.md),
  [0026](decisions/0026-emergency-stop-motion-gate.md),
  [0027](decisions/0027-arm-serial-protocol.md),
  [0028](decisions/0028-trophy-rules-and-scan-history.md),
  [0029](decisions/0029-arm-reach-gripper.md),
  [0030](decisions/0030-result-card-and-scan-history.md).

## Done (U2 Result Card & Scan History)

- Result card shows item/category, correct count, trophies, grade/level and "Scan lagi" / "Tutup".
- Completed sessions save a ScanRecord with JPEG crop; HistoryPill updates live.
- `waitingForRescan` pauses locks until rescan while preserving 0020 re-arm behavior.
- R1 DROP gate keeps rescan disabled until the drop completes; emits result/rescan telemetry.
- Tests: `live_scan_rescan_test.dart`, `result_card_test.dart` (5 viewports, no overflow, STOP reachable).
- H1: trophy/level rules, local ScanRecord JSON, responsive History; 33 new tests passed (444 total,
  with two known stale splash failures).

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
