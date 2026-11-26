# 0237 — MaixCAM2 drives the wheels through the Arduino on UART2

Date: 19 Nov 2026 · Status: accepted, deployed

## Context
The owner wired an Arduino running `codeMotorSlave.ino` (L298N, 9600 baud, one-char commands
`F B L R S`, polarity/swap config `1`–`6`) to the MaixCAM2's UART2 (`/dev/ttyS2`, B0 TX / B1 RX).
The app's `motor` message (`left`, `right`, signed PWM) only printed on the board, so the wheels
never moved. UART2 was also the ESP32 arm port (0235); the ESP32 is not wired.

## Decision
- `UART2_SLAVE = "arduino"` in `main.py` picks who owns UART2. With `arduino`, arm frames are not
  written (their digits 1–6 and CRC hex `B`/`F` would flip the Arduino's polarity and drive it);
  arm commands still answer. Set `esp32` to go back to the arm.
- `drive_char(left, right)` works like WASD: forward `(l+r)/2` vs turn `(l-r)/2`, the bigger wins
  (`F`/`B` or `R`/`L`); both under `DRIVE_DEADBAND` (10) → `S`. First version used the signs of
  left/right only: on the robot, stick jitter and ramp tails (`3,-3`, `17,-1`) became spins and the
  wheels flipped F→R→B, so they only nudged. Speed is ignored (the sketch drives ENA/ENB full on).
- Lines from the Arduino are logged as `[Drive] Arduino: …`; a `READY` while driving means it reset
  (motor start pulling its 5 V down).
- The last client leaving sends `S` (the Arduino keeps the last command).
- Watchdog: a moving command with no `motor` message for 500 ms → `S` (the app resends every 50 ms
  while the stick is held). Log is line-buffered and prints `[Drive] old -> new` on changes only.

## Consequences
Arm and wheels cannot share UART2. Running both needs the wheels on another UART (UART1) or a
shared protocol. No speed control until the sketch reads PWM.
