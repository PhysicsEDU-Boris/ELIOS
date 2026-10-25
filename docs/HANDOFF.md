# Handoff (Gemini)

## Where things stand

- Branch `feat/u1-control-layout` (at ea909e8, from `feature/live-scan` at 650752e).
  **Not pushed, no PR yet** (PRs #31-#37 merged; #24 draft).
- Never commit Xcode scheme, `Maixcam.txt`, `docs/module/`. Robot build: see CLAUDE.md.

## Done (U1 Desktop & Android Landscape, PRs #31-#37)

- Restored Figma 43:30 1-row layout across all devices down to Android landscape (`800x360`).
- Sized controls responsively for short landscape viewports (`<500 dp`): zero scrolling, `pinStop` false.
- Emergency STOP stays neatly seated under Speed slider in row 4; camera framed in `Flexible`.
- P1-E1b (#31-#37): parser, fake MaixCAM2 sim, R1 command link, class banks, motion gate.
- Scaled narrow portrait fallback (`390x844`) with `FittedBox` to prevent RenderFlex overflow.

## In progress

- Nothing open. U1 done and verified; next: user reviews, then push + PR.

## Not done / next step

- **U1 (ready for push + PR):** Control screen = Figma 43:30. Desktop & Android landscape 1-row
  down to `800x360` & `844x390`. PNGs in `docs/test-results/u1-control-layout/`.
- Next, in order: **L1** (fake = real robot; Notion "Robot link plan"), then **L0b** (serial
  protocol), then **L5 + U2**. R1-fw firmware only after ESP32 and Uno sketches exist.

## Tests (at ea909e8)

- `flutter analyze` clean (0 issues). Secret scan clean. Fake pytest 31 pass.
- `flutter test`: 407 pass, 2 fail (known stale splash in `test/widget_test.dart`).
- Layout tests: 44/44 pass (all 7 sizes x 6 states + break-checks).

## Decisions

- [0020](decisions/0020-lock-rearm-rule.md) re-arm, [0021](decisions/0021-manual-driving-orchestration.md) orchestration,
  [0022](decisions/0022-detection-protocol-distance-tags.md) detection protocol, [0023](decisions/0023-r1-command-link.md) R1 link,
  [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2, [0025](decisions/0025-bank-detector-class.md) bank class,
  [0026](decisions/0026-emergency-stop-motion-gate.md) emergency stop + watchdog spec. Older: [README](decisions/README.md).

## Test on the robot

- U1: 770x553 & Android landscape show full 1-row controls without scrolling; STOP under speed.
- STOP (button, Escape, space) stops **wheels only** with today's firmware; arm holds angle.
- Link loss: STOPPED banner; reconnect sends STOP + motor 0,0 first; open quiz stays usable.
- J1 guard: move arm-reach with quizzed object in view; no second quiz. R1=true: check status.
- M2d re-arm checks (pending): bottle locks 15 s after quiz; same-label waits 2 s; check JSONL.
