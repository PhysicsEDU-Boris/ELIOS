# Handoff

## Where things stand

- Branch `feat/u1-control-layout` (from `feature/live-scan` at 650752e): U1 done at b9fbaa8,
  **not pushed, no PR yet**. PRs #31-#37 are merged; #24 (grounded quiz) stays a draft.
- Never commit the Xcode scheme, `Maixcam.txt` or `docs/module/`. Robot build: CLAUDE.md; check `appCommit` in the JSONL.

## Done (24-25 Oct, PRs #31-#37)

- P1 (#31): optional `track_id`, `dist_cm`, `lateral_cm` and `arm_tags` are parsed.
- T1 / T1b (#32, #35): a fake MaixCAM2 on robotic_hand_sim with photo cards and occlusion.
- R1 (#33): the orchestration state machine and the app-to-MaixCAM2 command link, tested on a
  simulated robot only.
- B1 (#34): bank questions follow the detector class, not Gemma's words.
- E1 / E1b (#36, #37): the emergency stop and one motion gate. STOP sits in its own rail; link
  loss means STOPPED; a 4 Hz heartbeat; the J1 guard; no scanning while STOPPED.

## Not done / next step

- **U1 (done, needs push + PR):** Control screen = Figma 43:30. Wide one row; under 1100 px camera
  on top; scrolls when short. STOP 74 px under the speed slider + a STOP pill in the quiz header.
  Leaf reopens a minimised quiz. Debug items in the Debug Scan side sheet (debug builds only).
  PNGs in `docs/test-results/u1-control-layout/` (`U1_PNG=true`). Trophy count: placeholder (U5).
- Next: R1-fw in `main.py` (0023 command link + 0026: HEARTBEAT, 1 s watchdog, STOP, ≤ 200 ms
  wheel refresh, `arm_moving`); Uno/ESP32 sketches (outside this repo); arm bring-up, M4, R2, CI.
- Quiz: the owner reviews the banks, then the accepted-filter task.

## Tests (at b9fbaa8)

- `flutter analyze` is clean. `flutter test` gives 395 passed and **2 failed**: the known-stale
  splash tests in `test/widget_test.dart`.
- The fake's pytest: 31 pass (needs `ROBOTIC_HAND_SIM` or the sim next to the repo).
- `scripts/check-secrets.sh` is clean. The macOS robot build compiles.

## Decisions

- [0020](decisions/0020-lock-rearm-rule.md) re-arm (+ link drop, J1 guard),
  [0021](decisions/0021-manual-driving-orchestration.md) orchestration (proposed),
  [0022](decisions/0022-detection-protocol-distance-tags.md) detection protocol,
  [0023](decisions/0023-r1-command-link.md) R1 + command link, [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2,
  [0025](decisions/0025-bank-detector-class.md) bank by detector class,
  [0026](decisions/0026-emergency-stop-motion-gate.md) emergency stop + watchdog spec. Older: [README](decisions/README.md).

## Test on the robot

- U1: resize the window (wide, 770x553, narrow): nothing cut off, the page scrolls. STOP under
  the speed slider, the quiz-header STOP, Escape and space all stop; Debug Scan opens the sheet.

- STOP (button, Escape, space) stops the **wheels only**: today's firmware ignores STOP and
  HEARTBEAT, so the arm keeps its last angles. **Before any arm test near people:** R1-fw, the
  sketch watchdogs, and a physical e-stop.
- Link loss: STOPPED, and STOP + motor 0,0 first on the reconnect. No new quiz until
  "Lanjutkan"; an open quiz stays usable.
- J1 guard: move the arm-reach slider with a quizzed object in view; it must not be quizzed
  again.
- M2d re-arm checks (not run yet): a bottle locks 15 s after a quiz while the quizzed peel stays
  in view; same-label objects wait 2 s; check `livescan-*.jsonl`.
- `--dart-define=R1=true` should show "R1: robot tidak terhubung" with today's firmware.
