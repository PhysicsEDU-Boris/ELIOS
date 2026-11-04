# MaixCAM2 firmware (m2c-track-v1)

Deployed on the robot 16 Oct 2026: scan JSONL `firmwareSha256`
`bbb3595e8070d4fab421ce38d5a9becbca26f6bcc8c34be4d7e29ed5c2ab79e6` matches
`shasum -a 256 main.py`.

## MaixVision package

`app.yaml` is the MaixVision app manifest (`elios_clean_m2c_v1` v1.0.0, files:
`main.py`). The package `dist/maix-elios_clean_m2c_v1-v1.0.0.zip` is a build
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
   MaixPy, numpy, websockets and AP configuration. Do not deploy the test file.
   Do not run a second server beside the existing port-8765 process.
3. Restart the existing robot application using your normal deployment workflow.
   Its console must print `[Firmware] m2c-track-v1 <sha256>`.
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
  x/y, w, h, label, score; the tracked box also has `track_id`. Hands are held between
  detection frames; the tracked box is fresh every frame.
- `arm_tags`: AprilTag TAG36H11 ids 0 and 1 seen at the last detection frame:
  `id`, `cx`, `cy`, and `dist_mm` with `dist_rough: true` (nominal lens, not calibrated).
- Every `DET_EVERY_N_FRAMES`-th frame: `detection_frame_id == frame_id` and
  `clean_detections` (same list). When it is nonempty, `clean_image` is the same JPEG
  as `image` (no second encode), so older apps keep pairing.
- Commands: `{"cmd":"track_start","box":[x,y,w,h],"label":"kardus"}` (top-left x/y in
  stream pixels) answers `{"event":"track_started","track_id":n}` or
  `{"event":"track_error","error":...}`; `{"cmd":"track_stop"}` answers `track_stopped`.
  A track stops by itself after `TRACK_LOST_FRAMES` low-score frames.
- A `[FPS]` line every 5 s on the console gives fps and ms per stage.
