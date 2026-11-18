# 0230: Sync with robotic_hand_sim 75ab797 (arm hardware, firmware protocol, MaixCAM2 wiring)

- Status: Accepted for the app, the fake MaixCAM2 and the docs. The MaixCAM2 bridge (0023 R1-fw)
  and the transport choice (section 5) stay open for the owner.
- Date: 2026-11-19
- Supersedes: the "MaixCAM2 to ESP32" section and the joint table of [0027](0027-arm-serial-protocol.md).
  Amends [0023](0023-r1-command-link.md) ("neither slave has feedback").
- Source: `github.com/3dbore/robotic_hand_sim` at `75ab797` (19 Nov 2026). In that repo the active
  code is `hil/` (`hil/config.py` is the hardware source of truth) and the firmware is
  `slave_code/6-axis-esp32-twoway-tmc2208/`. `hil_toolkit/` is the older app and is now out of date.

## 1. What changed in the sim

| | 0027 (old) | Sim 75ab797 |
|---|---|---|
| Frame | `D2,D3,D4,D5,D6,D8\n`, whole degrees | `F0,F1,F2,F3,F4,F5,CC\n`, at most one decimal, `CC` = CRC-8 (poly 0x07, init 0) of everything before the last comma, two hex digits. Bad frames are dropped whole |
| Field order | Gripper, Yaw, Pitch, Arm B, Arm A, Base | unchanged |
| Base (J1) | servo, sim ±90 | NEMA17 on a TMC2208 (80T→120T). Wire −90..270, home 90, sim ±180, never continuous. No homing switch: it must be at home at power-up. Empty field disables the driver but keeps the step count |
| Speed | 60 deg/s on every joint | per axis: Gripper 90, Yaw 45, Pitch 45, Arm B 30, Arm A 30, Base 40 deg/s, with acceleration limits |
| Feedback | none | `BOOT reason=..` at start-up and `STAT rx= bad= i2c= fix= reinit= spike= out=..` every second |
| Commands | stream only | stream, plus two-way: `V`, `C`, `H`, `M`, `X` → `OK` / `ACK t=` / `DONE q=` / `ERR reason=`. Repeating a `SEQ` repeats only the answer. In two-way mode the ESP32 solves the IK and plans a smooth move |
| Glitch guard | none | a jump over 20 deg needs two agreeing frames; targets are low-passed (150 ms) before the speed limit |
| Safety | none | tank keep-out behind the base (Y > 0 and Z < 167 mm); the base cannot pass ±90 deg until the arm is raised. Enforced by the PC planner `hil/kinematics.py`; not checked whether the ESP32 enforces it too |
| Baud | 9600 | 9600 (both sides must match) |

`DONE` means the board finished commanding the move plus 150 ms, not that the arm got there:
MG996R servos and the open-loop stepper report no shaft position.

## 2. Joint table (replaces 0027's)

`servo = home + sim angle`, no scaling. Trim and invert act only on the wire value.

| Field | Axis | Home (servo) | Effective sim range | Speed deg/s |
|---|---|---:|---:|---:|
| F0 | Gripper | 180 (open) | servo 60..180, closed 75 (+ offset) | 90 |
| F1 | Wrist Yaw (J5) | 90 | −90..+90 | 45 |
| F2 | Wrist Pitch (J4) | **0** (was 90) | 0..180 | 45 |
| F3 | Arm B (J3) | 180 | −180..0 | 30 |
| F4 | Arm A (J2, mirrored pair) | 90 | −50..+50 | 30 |
| F5 | Base (J1, stepper) | 90 | −180..+180 | 40 |

The home EE point is unchanged: J4 at (0, −42.5, 90) mm.

Gripper: the app keeps sending width 0..100 (0 open). The MaixCAM2 maps it to
`servo = 180 − 1.05 × width` (0 → 180 open, 100 → 75 closed). 0027's `10 + 0.8 × width` is retired.

## 3. What the app changes

- The app-to-MaixCAM2 JSON (0023, 0027 "App to MaixCAM2") is **unchanged**. The app never sends
  servo frames itself.
- `armTimeout` 15 → 30 s and `waitCap` 120 → 180 s (`lib/services/robot/r1_constants.dart`): a full
  Arm B travel now takes 6 s, not 3 s, so a four-segment PICK needs about 24 s plus settling.
  Pinned by `test/robot/arm_timing_test.dart`.
- Fake MaixCAM2 (`tools/fake_maixcam/`): per-joint speeds from the firmware instead of 60 deg/s, and
  effective joint limits from `hil/config.py` instead of the legacy `hil_toolkit`.

## 4. MaixCAM2 → ESP32 (for R1-fw)

Use the sim's protocol unchanged, so the PC toolkit and ELIOS drive the same firmware:

- joystick and `HOLD`: stream frames at up to 20 Hz, all six fields always filled;
- `HOME` → `H`, `PICK` / `MOVE_TO_BIN` / `DROP` → `M` (and gripper), `STOP` → `X`. The app's
  `motion_done` comes from the board's `DONE`; `ERR` maps to the 0023 `error` reply;
- forward `BOOT` and rising `STAT` counters to the app; a `BOOT` mid-session means the arm pose is
  unknown (0027 "Boot, feedback").

## 5. MaixCAM2 wiring (proposal, owner to confirm)

From the MaixCAM2 Pins v1.0 diagram. I/O is 3.3 V; never connect 5 V to a pin.

| Link | UART | Pins | Device |
|---|---|---|---|
| ESP32 arm | UART2 | B0 TX, B1 RX (left 2×6 header, labelled U2T/U2R) | `/dev/ttyS2` |
| Arduino wheels | UART1 | A30 TX, A31 RX (right header; set with `pinmap` first) | `/dev/ttyS1` |
| Not used | UART0 | A28 / A29 | system console and log |
| Spare | UART3 (B2/B3), UART4 (A21/A22, 1.25 mm 6-pin) | | |

Cross TX/RX and share GND. The Uno's 5 V TX needs a divider (1 kΩ series, 2 kΩ to GND) into A31.
Raising the baud to 115200 on both ends is proposed (a 36-byte frame at 20 Hz uses ~75 % of 9600);
it needs `SERIAL_BAUD` changed in the `.ino` and `hil/config.py`. The wheels need a watchdog
(stop if no frame for 300 ms); today a lost link leaves them running.

## Open

- Which firmware is on the robot now (servo base or TMC2208 base), and is the base at home at power-up.
- Baud rate and wheel transport (own UART, or through the ESP32).
- The joystick spec (task J1) still assumes base ±90, 60 deg/s, whole degrees and no CRC; revise it
  against this doc before sending it.
- Does the ESP32 two-way mode enforce the tank keep-out, or only `hil/` on the PC.
