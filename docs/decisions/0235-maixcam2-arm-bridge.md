# 0235 — MaixCAM2 arm bridge to the ESP32, with the DROP guard

Date: 19 November 2026. Branch `feat/maixcam2-arm-bridge`, stacked on `feat/arm-kinematics` (0234).
Firmware `m2c-arm-v1`, MaixVision package v1.2.0. **Not deployed or run on the robot yet.**

## Owner answers (19 Nov)

ESP32 on UART2 (B0 TX, B1 RX) running `6-axis-esp32-twoway-tmc2208`; 9600 baud; PICK stays manual
(gripper fader); the base stepper is at home at power-up; wheels later. The tank check on the board:
left to me; done (cheap, and it protects against an old app or a script).

## Design

- **Stream mode, not two-way `M`.** The ESP32's `M` takes an x/y/z point and moves in a straight
  line by its own IK, which is not the joint-space path the app checked against the tank. Stream
  mode is what the PC toolkit (`hil/motion.py`) uses: the MaixCAM2 plays each leg itself (all
  joints start and arrive together, smoothstep, 80 % of each axis' speed) and sends 20 frames a
  second `F0..F5,CC` (CRC-8 poly 0x07). Trim and invert from the app's CONFIG are applied to the
  wire value only, as `hil/config.py Axis.wire`.
- `firmware/maixcam2/arm_bridge.py`: plain Python (no Maix imports), tested off the board. Runs in
  its own 20 Hz thread in `main.py` with a lock; replies go back through the WebSocket loop.
- **Nothing is streamed before the first move**, so the servos stay as they booted. The ESP32 takes
  the first frame after a release as the servo's start position, so the arm must be at home at
  power-up (owner: it is).
- **Last-line checks** before anything reaches the ESP32: each pose inside its axis range, every leg
  clear of the tank (same FK and tank test as the app; pinned to the sim by the shared golden file
  `test/fixtures/arm_kinematics_golden.json`).
- **DROP guard**: DROP plays the bin's release steps only if MOVE_TO_BIN finished, the arm has not
  moved since, and that bin's AprilTag (2 / 3 / 4) was seen within 2 s (`on_tags` from the frame
  pusher, so tag search must be on, which R1 does). Otherwise `not_at_bin` / `bin_not_confirmed`.
- **Watchdog** (0026): no app message for 1 s during a move → the arm holds (frames continue at the
  held pose; never released), `error watchdog` to the app. App disconnect → hold.
- **ESP32 `BOOT`** mid-session: the arm may have dropped, so streaming stops and only HOME moves it
  (directly to home; `motion_done` after 6 s, the slowest full travel, not a measured arrival).
  Put the arm near home by hand first. `STAT` / `BOOT` lines are kept and returned in STATUS.
- The pose last sent rides on `motion_done` and STATUS (`servo`); the app syncs its planner from it,
  so after a STOP or an R1 sort it asks STATUS and knows the arm's pose again (0234's "Press HOME
  first" now only after an ESP32 reset).
- `MOVE_TO_BIN` / `DROP` plan each saved step through the tank planner (as the sim plays a sequence)
  and wait each step's hold time. Only B3 has a sequence.
- `PICK` → `not_implemented` (owner: manual). R1's automatic sort therefore stops at PICK on this
  firmware; R1 is only in `--dart-define=R1=true` builds, so the robot build is not affected.
- `LOCK_DRIVE` / `UNLOCK_DRIVE` answer `ack`; the wheels (UART1) are a later task.

## Not checked

- The MaixPy calls on the board: `maix.uart.UART("/dev/ttyS2", 9600)`, `write_str`, `read(-1, 0)`.
  If no `STAT` line ever arrives, the UART2 pins may need `pinmap` first.
- 9600 baud with 20 frames a second (~75 % of the line): if `STAT bad=` rises, lower the rate.
- Whether the ESP32 itself checks the tank (0230: not known). The board and the app both do.

## Tests

`firmware/maixcam2/test_arm_bridge.py` (20): frames and CRC, trim/invert, kinematics and planner vs
the golden file, ARM_POSE timing / refusals / replacement, planned HOME, STATUS / PICK, B3 sequence,
DROP guard (no tag, wrong tag, stale tag, moved away), busy, watchdog, HOLD, ESP32 reset, STAT,
CONFIG order and persistence. Break-checked: DROP guard, board tank check, watchdog.
`test_clean_stream.py`: the frame pusher feeds tag ids to the bridge. App: `ArmPose.sync` test.
