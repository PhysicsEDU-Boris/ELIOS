# Handoff

## In progress

- L2/L4 MaixCAM2 work is on `feat/l2-l4-arm-firmware`, based on `58fd087`.
- Authenticated single-client heartbeats, 1 s watchdog expiry, conservative STATUS, and logical-only STOP/HOLD are mock tested.
- Current Flutter sends no bearer header; arm control stays unavailable. Plain `ws://` also exposes any configured bearer token on the LAN.
- Physical output is disabled. No hardware deployment or actuation has been performed.
- ESP32 and Uno sketches remain owner-owned; see decision 0027 and firmware README.

## Done (25-26 Oct)

- U1 Control screen = Figma 43:30 (#38); G1c STOPPED never shrinks the camera (#45).
- L1 fake = real robot: PICK / MOVE_TO_BIN / DROP with IK, driving, servos, 5 `r1_*` scenarios (#39).
- G1 reach/gripper and G1b locked-frame capture (#41-42); H1 history (#40); U2 result card (#43).
- G2a arm serial protocol + fake HOME / height / STATUS `ee_mm`, `at_home` (#44); G2b app HOME,
  ARM HEIGHT, tag chips and EE readout (#46).

## Next

1. Gemini: G2c HOME slider reset, STATUS refresh, ScanRecordStore persistence, local-history label,
   and difficulty count.
2. Owner: ESP32 D7 mirror, joint clamps, 60°/s motion, UART receive/hold/STOP, boot-only home,
   Uno watchdog/wheel-off path and physical calibration. Define a safe waypoint before bin-to-home.
3. L5 R1 student flow; U3 answer feedback; U4 essay rubric; U7 Firebase; U8 docs.
4. Open: driving can re-quiz the same object (guard covers J1 only); lateral X disabled (needs J1).

## Checks and hardware gate

- Arm tests: `python3 -m unittest discover -s firmware/maixcam2 -p 'test_arm*.py'`.
- Stream regression: `python3 -m unittest firmware/maixcam2/test_clean_stream.py`.
- Before any arm test: owner supervision, ESP32/Uno watchdogs, and a physical power-cut e-stop.
- Confirm D8's planetary ratio, gripper endpoints, camera distance calibration, and the robot IP.
- Never infer physical home from a MaixCAM2 reboot or report simulated tests as hardware validation.
