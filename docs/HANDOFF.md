# Handoff

- Base `feature/live-scan` at 650752e; HEAD on `feat/u1-control-layout` (PR open, not merged).
  PRs #31-#37 merged; #24 stays draft. Never commit Xcode scheme, `Maixcam.txt`, `docs/module/`.

## Done (U1 Control screen layout)

- Control screen = Figma 43:30 1-row layout across desktop & Android landscape (`800x360`–`1366x768`).
- Short landscape responsive sizing (`<500 dp`): 180 dp sliders, 48 dp D-pad, 140 dp speed, 64 dp STOP.
- STOP stays seated under speed slider with 0 scroll; camera framed in `Flexible` (`maxHeight: 220 dp`).
- Symmetrical phone portrait (`390x844`) fallback with `FittedBox` motion row and pinned STOP.
- 44 layout tests passing (7 sizes × 6 states); generated PNGs in `docs/test-results/u1-control-layout/`.

## R1 (0023)

- Simulated robot only; `--dart-define=R1=true` shows "R1: robot tidak terhubung" on today's firmware.
- Waits on R1-fw and M4 screens. STOP stops wheels (motor 0,0); arm holds last angles until R1-fw.

## M2d robot test (not run yet; fake scenarios cover most)

- Quizzed peel in view: bottle locks 15 s after quiz closes; second bottle waits 2 s; check JSONL.

## Quiz state

- Bank is default source (0018/0019); detector class picks questions (0025); owner reviewing banks.
- Next quiz task: accepted-filter, kardus Q1, level chip vs Mudah-first, generic Q5.

## Next tasks, in order

1. **L1** (in progress by another agent; fake = real robot; Notion "Robot link plan").
2. **L0b** (serial protocol), then **L5 + U2**. R1-fw only after ESP32 & Uno sketches exist.
3. Arm bring-up (ESP32 UART), camera calibration (0022), M4 overlay, R2, CI, M5 Android.

## Known open

- Image identify first token 7-9 s; chat interrupting scan waits up to 8 s for cancelled call (0003).
- 2 stale splash tests (`test/widget_test.dart`); yellow cup scores 39-56%.

## Decisions

- [0020](decisions/0020-lock-rearm-rule.md) re-arm, [0021](decisions/0021-manual-driving-orchestration.md) orchestration,
  [0022](decisions/0022-detection-protocol-distance-tags.md) detection protocol, [0023](decisions/0023-r1-command-link.md) R1 link,
  [0024](decisions/0024-fake-maixcam-sim.md) fake MaixCAM2, [0025](decisions/0025-bank-detector-class.md) bank class,
  [0026](decisions/0026-emergency-stop-motion-gate.md) emergency stop + watchdog spec.
