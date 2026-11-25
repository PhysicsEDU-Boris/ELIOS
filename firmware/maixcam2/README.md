# MaixCAM2 firmware (m2c-arm-v3)

v3 (0240 section 9, package 1.4.0): ~20 fps stream, video lag guard (frames skipped, never queued),
UART reads only when bytes are waiting, bin sequences pause on a briefly quiet app. Restart without the
touchscreen: `app.switch_app("elios_clean_m2c_v1")` in a separate python3, then stop the running app (or
the launcher UI); the launcher daemon starts it.

v2 (0240, package 1.3.0): arm ESP32 on UART4 (`/dev/ttyS4`, A21/A22), wheels Arduino on UART2
(`/dev/ttyS2`, one char F/B/L/R/S), AprilTag base centring in bin sequences. Console prints
`[Arm] UART /dev/ttyS4 9600 open` and `[Drive] UART /dev/ttyS2 9600 open`.


Deployed on the MaixCAM2 19 Nov 2026 (over USB, `/maixapp/apps/elios_clean_m2c_v1`, v1.2.0):
`{"cmd":"ping"}` returns `m2c-arm-v1` and `firmware_sha256`
`17c1204f758f14e41687f3652a06f3e0adf93e98f0741e8928d5032d2a8d2230`, matching
`shasum -a 256 main.py`. ESP32 not wired yet, so no `STAT` line seen. The board ran the
floor-distance-guides build (0192, v1.1.0, sha256 `2149d09f…`, not on this branch; its tag id 2
is the 80 mm floor tag). It is backed up on the board in
`/root/backup/elios_clean_m2c_v1_2026-11-08/`; restore those files and remove `arm_bridge.py`
and `bin_sequences.json` to roll back. Floor guides are off until 0192 is merged (tag id clash).

## MaixVision package

`app.yaml` is the MaixVision app manifest (`elios_clean_m2c_v1` v1.2.0, files:
`main.py`, `arm_bridge.py`, `bin_sequences.json`; all three must be deployed together). The package `dist/maix-elios_clean_m2c_v1-v1.0.0.zip` is a build
output (exactly `app.yaml` + `main.py`), so it is gitignored; rebuild it from
these two files in MaixVision. Bump `version` when `main.py` changes.

Deployable entry point: **main.py** in this directory. It is a complete copy
of the owner's local Maixcam.txt reference with the clean-image stream change.
Reference SHA-256: `da57d135a004e399a4a4bb7a8c132209ce340fc3565856640d70bc2f5734a0cc`.
Maixcam.txt itself remains untracked and unchanged. The reference has not been
verified byte-for-byte against the robot's currently installed script.

## Owner deployment

1. Export/back up the **currently running** robot main.py through your existing
   MaixVision/SSH workflow. Record its active project/boot path and SHA-256.
   Compare it to the reference above before replacing it; if it differs, review
   those changes first so device-specific behavior is not lost. This reference's
   motor/servo handlers only print commands; it does not add hardware actuation.
2. Deploy this directory's `main.py` to that confirmed active entry-point path,
   retaining `/root/models/mixformer_v2.mud`, `hand_landmarks.mud`, `hand_detector.mud`, `anchors.csv`,
   MaixPy, numpy, websockets and AP configuration. Deploy `arm_bridge.py` and
   `bin_sequences.json` next to `main.py`. Do not deploy the test files.
   The arm's CONFIG (trims, inverted) is kept in `/root/elios_arm_config.json`.
   Do not run a second server beside the existing port-8765 process.
3. Restart the existing robot application using your normal deployment workflow.
   Its console must print `[Firmware] m2c-arm-v1 <sha256>` and `[Arm] UART /dev/ttyS2 9600 open`.
   Compare that hash with the local result of:
   `shasum -a 256 firmware/maixcam2/main.py`.
   The hash is also returned by `{"cmd":"ping"}` and included in scan JSONL
   as `firmwareSha256`. A version string alone is not a deployment check.
4. Build the matching app from this branch:
   `flutter build macos --debug --dart-define=LIVE_SCAN=true --dart-define=APP_COMMIT=$(git rev-parse --short HEAD)`.
   Quit the previous app, then `open build/macos/Build/Products/Debug/ELIOS.app`.
5. To roll back, restore the backed-up robot script at the same active path and
   restart. The new app will retain preview/controls but cannot identify from
   that old annotated-only stream; use the previous app only if needed for
   historical behavior, knowing it sends annotated pixels to Gemma.

## Wire contract (m2c-track-v1, decision 0182)

- No model draws on the frame: `image` is the clean camera JPEG (640x480).
- `vision_protocol: 1`, increasing `frame_id`, `firmware_sha256`: every message.
- `detections`: the tracked box (after `track_start`) plus `Human_Hand` boxes, centre
  x/y, w, h, label, score; the tracked box also has `track_id`. Both are fresh on
  detection frames and held in between (MixFormerV2 costs ~63 ms a call).
- `arm_tags`: AprilTag TAG36H11 ids 0 and 1 seen at the last detection frame:
  `id`, `cx`, `cy`, and `dist_mm` with `dist_rough: true` (nominal lens, not calibrated).
- `image` is the live preview at JPEG quality 60. Every `DET_EVERY_N_FRAMES`-th frame:
  `detection_frame_id == frame_id` and `clean_detections` (same list). At most every
  `CLEAN_EVERY_MS` (700 ms) one of them also carries `clean_image`: the same frame at quality 80
  for the AI (LOCK and refine use one up to 1 s old).
- Commands: `{"cmd":"track_start","box":[x,y,w,h],"label":"kardus"}` (top-left x/y in
  stream pixels) answers `{"event":"track_started","track_id":n}` or
  `{"event":"track_error","error":...}`; `{"cmd":"track_stop"}` answers `track_stopped`.
  A lost item is not dropped: after `TRACK_REFIND_AFTER` low-score calls the tracker searches
  the whole frame, and the box comes back with the same `track_id` when it finds the item.
- A `[FPS]` line every 5 s on the console gives fps and ms per stage.

## Arm bridge (m2c-arm-v1, decision 0235)

- ESP32 `6-axis-esp32-twoway-tmc2208` in stream mode on UART2 (`/dev/ttyS2`, B0 TX, B1 RX), 9600 baud.
  20 frames a second `F0..F5,CC` once the app has moved the arm; nothing before (the servos stay as
  they booted). Every field is filled; the arm is never released by the MaixCAM2.
- 0023 commands answer `ack`, then `motion_done` (with `servo`, the pose last sent) or `error`:
  `STATUS` (also `at_home`, `servo`, `esp32_boot`, `esp32_stat`), `ARM_POSE` (0234), `HOME`
  (planned around the tank), `MOVE_TO_BIN` / `DROP` (bin_sequences.json; B3 only for now),
  `HOLD`, `STOP`, `CONFIG`, `LOCK_DRIVE` / `UNLOCK_DRIVE` (ack only, wheels later), `PICK`
  (`not_implemented`: picking is manual).
- Refusals: `invalid_path`, `out_of_range`, `tank` (checked again on the board), `busy`,
  `pose_unknown` (after an ESP32 `BOOT`: HOME first), `no_sequence`, `not_at_bin`,
  `bin_not_confirmed` (DROP guard: that bin's tag must be seen within 2 s at the state point),
  `watchdog` (no app message for 1 s: the arm holds).
- `arm_tags` also reports bin tags 2 (anorganik), 3 (organik), 4 (B3).
