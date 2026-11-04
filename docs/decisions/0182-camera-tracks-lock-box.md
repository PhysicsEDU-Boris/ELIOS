# 0182: The camera tracks the LOCK box; hands and arm tags; no waste model

- Status: Accepted (owner, 3 Nov 2026: step 2 of "drop the .mud model, Gemini box on LOCK,
  tracking after the lock, AprilTags for the arm"); robot-tested 4 Nov (see below)
- Date: 2026-11-04
- Builds on: [0181](0181-lock-button-ai-box.md) (LOCK box), [0180](0180-segmentation-and-fps-options.md)
  (FPS), [0022](0022-detection-protocol-distance-tags.md) (`track_id`, `arm_tags`),
  [0027](0027-arm-serial-protocol.md) (hand pause), [0178](0178-robot-wifi-qr-setup.md) (Wi-Fi QR, kept).

## Decision

`firmware/maixcam2/main.py` (`m2c-track-v1`, started from the camera's live `feat/wifi-qr-setup`
file so the Wi-Fi QR setup stays):

- **No waste model.** `elios_waste_seg.mud` is not loaded (it stays on the camera). Nothing is
  drawn on frames, so `image` is the clean frame. Stream is 640x480 (was 640x640, the model's
  input).
- **Tracking.** `{"cmd":"track_start","box":[x,y,w,h],"label":"..."}` (top-left x/y, stream
  pixels, validated and clipped) starts `nn.MixFormerV2` (`mixformer_v2.mud`) on the next
  detection frame and answers `track_started` with a new `track_id`; `track_stop` ends it. The box
  goes out in `detections` (centre x/y, w, h, label, score, `track_id`). Score < 0.5: not sent
  that frame; 15 low calls in a row (~3 s): tracking stops, a new LOCK is needed. ByteTrack is
  not used: it needs a detector on every frame.
- **Hands.** `nn.HandLandmarks` (`hand_landmarks.mud`, which runs `hand_detector.mud`) at conf
  0.7; each hand goes out as `Human_Hand`, boxed by its 21 landmarks (the model's own box is a
  300-770 px square crop), so `r1_orchestrator`'s pause (score ≥ 0.5) keeps working.
- **Arm tags.** `find_apriltags` TAG36H11 on a 320x240 copy (640x480 kills the process, no Python
  error); ids 0 (arm5 bottom, 18.52 mm) and 1 (arm3 rear, 10 mm). `arm_tags` entries carry `id`,
  `cx`, `cy` and a **rough** `dist_mm` with `dist_rough: true`: pinhole with the nominal 81°
  FOV (`fx` ≈ 375 px), not calibrated. Replace `NOMINAL_FX` after the calibration in
  robotic_hand_sim `docs/camera_calibration.md`.
- **Cadence.** Tracker, hands and tags run every 2nd frame and are held in between. MixFormerV2
  costs about 63 ms a call; on every frame the stream fell to 8 fps.
- **Protocol.** `vision_protocol: 1` stays. On detection frames `clean_detections` = that frame's
  list and, when it is nonempty, `clean_image` = the same JPEG as `image` (no second encode), so
  0181 builds pair it as before. A `[FPS]` console line every 5 s gives ms per stage.

## Robot test (4 Nov, real MaixCAM2 over Wi-Fi, Mac WebSocket client; the app does not send `track_start` yet)

| Firmware | fps | detection frames/s | image (base64) |
|---|---|---|---|
| m2c-clean-v1 (seg model, 640x640) | 10.4 | 5.2 | 84 KB |
| m2c-track-v1, nothing locked | 17.0–19.8 | 8.5–9.9 | 64–77 KB |
| m2c-track-v1, tracker every frame | 8.2 | 4.1 | 77 KB |
| m2c-track-v1, tracker every 2nd frame, locked | 10.5 | 5.3 | 73 KB |

- A cigarette pack locked from a fresh frame: the box followed it while it was moved and lifted by
  hand (score 0.65–1.0). An open palm over it lost the track; the box did not jump to the hand,
  and tracking stopped 3 s later.
- A box sent from an older frame (the scene had shifted) was tracked on background at score 1.0:
  MixFormerV2 follows whatever patch it gets. **App step 3 must send the box of the frame it gave
  Gemini**, and the item should stay still until LOCK answers (~2 s).
- Hands: 58 of 644 frames, score 0.81–0.996. The square-crop boxes led to the landmark boxes
  above; the landmark boxes are covered by a unit test and have not been checked again on the robot.
- AprilTags: none in view, so the tag path ran but `arm_tags` stayed empty; distance not checked.

## Not in this step

- App step 3 (LOCK sends `track_start`, the green box follows `track_id`, the arm uses it): only if
  the owner asks.
- The live scan's own auto-lock now sees the tracked box (label = the AI's name) and hands only.
- Calibration (`dist_cm`, `lateral_cm`, exact `dist_mm`).

## Tests

`firmware/maixcam2/test_clean_stream.py`: box validation, tracker init/follow/lose, landmark hand
boxes, tag ids and rough distance (no NaN on the wire), half-size tag search, and the real
`ws_frame_pusher` with fakes (one JPEG per frame, `clean_image` == `image`, held boxes). The new
tests fail on the old firmware (break-check). Wi-Fi and dashboard tests unchanged.

## Rollback

On the camera: `cp /root/main.py.pre-track.bak /maixapp/apps/elios_clean_m2c_v1/main.py` (and
`/root/app.yaml.pre-track.bak` to `app.yaml`), then close and reopen ELIOS Clean Vision.
