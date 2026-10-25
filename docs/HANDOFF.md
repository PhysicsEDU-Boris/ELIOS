# Handoff

## Where things stand

- Branch `feat/u1-control-layout` (from `feature/live-scan` at 650752e): U1 + the fold fix,
  **not pushed, no PR yet**. PRs #31-#37 are merged; #24 (grounded quiz) stays a draft.
- Never commit the Xcode scheme, `Maixcam.txt`, `docs/module/`. Robot build: see CLAUDE.md.

## Done (24-25 Oct, PRs #31-#37)

- P1 (#31): optional `track_id`, `dist_cm`, `lateral_cm` and `arm_tags` are parsed.
- T1 / T1b (#32, #35): a fake MaixCAM2 on robotic_hand_sim with photo cards and occlusion.
- R1 (#33): orchestration state machine + app-to-MaixCAM2 command link (simulated robot only).
- B1 (#34): bank questions follow the detector class, not Gemma's words.
- E1 / E1b (#36, #37): emergency stop, one motion gate, link loss = STOPPED, 4 Hz heartbeat, J1 guard.

## In progress

- Nothing open. U1 fold fix done (STOP above the fold at every size); next: push + PR.

## Not done / next step

- **U1 (done, needs push + PR):** Control screen = Figma 43:30. Desktop & Android landscape
  1-row down to 700x360; tidy phone portrait with pinned STOP. STOP under speed slider + in quiz
  header. Leaf reopens minimised quiz. PNGs: `docs/test-results/u1-control-layout/`.
- Next, in order: **L1** (the fake behaves like the real robot; Notion "Robot link plan"), then
  **L0b** (serial protocol), then **L5 + U2**. R1-fw (`main.py`: HEARTBEAT, 1 s watchdog, STOP,
  `arm_moving`) only after the ESP32 and Uno sketches exist. Later: arm bring-up, M4, R2, CI.
- Quiz: the owner reviews the banks, then the accepted-filter task.

## Tests (at cdcbf1a)

- `flutter analyze` clean. `flutter test`: 407 pass, 2 fail (stale splash in `test/widget_test.dart`).
- Fake's pytest 31 pass. Secret scan clean. Layout tests (44 cases) and break-checks pass.

## Decisions

- [0020](decisions/0020-lock-rearm-rule.md) re-arm (+ link drop, J1 guard),
  [0021](decisions/0021-manual-driving-orchestration.md) orchestration (proposed),
  [0022](decisions/0022-detection-protocol-distance-tags.md) detection protocol,
  [0023](decisions/0023-r1-command-link.md) R1 + command link, [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2,
  [0025](decisions/0025-bank-detector-class.md) bank by detector class,
  [0026](decisions/0026-emergency-stop-motion-gate.md) emergency stop + watchdog spec. Older: [README](decisions/README.md).

## Test on the robot

- U1: at 770x553 STOP, D-pad and sliders show without scrolling; a very short window pins STOP
  bottom right. The quiz-header STOP, Escape and space stop too; Debug Scan opens the sheet.
- STOP (button, Escape, space) stops the **wheels only**: today's firmware ignores STOP and
  HEARTBEAT, so the arm keeps its last angles. **Before any arm test near people:** R1-fw, the
  sketch watchdogs, and a physical e-stop.
- Link loss: STOPPED, and STOP + motor 0,0 first on the reconnect. No new quiz until
  "Lanjutkan"; an open quiz stays usable.
- J1 guard: move the arm-reach slider with a quizzed object in view; no second quiz. R1=true:
  "R1: robot tidak terhubung" with today's firmware.
- M2d re-arm checks (not run yet): a bottle locks 15 s after a quiz while the quizzed peel stays
  in view; same-label objects wait 2 s; check `livescan-*.jsonl`.
