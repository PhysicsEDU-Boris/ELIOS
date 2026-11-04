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
  and tracking stopped 3 s later. (`docs/test-results/0182/track-pack-and-hand.jpg`)
- A box sent from an older frame (the scene had shifted) was tracked on background at score 1.0:
  MixFormerV2 follows whatever patch it gets. **App step 3 must send the box of the frame it gave
  Gemini**, and the item should stay still until LOCK answers (~2 s).
- Hands: 58 of 644 frames, score 0.81–0.996, but boxed by the model's square crop. After the
  switch to landmark boxes: an open hand moved around in 162 of 259 frames (17.2 fps), each box
  fitting the hand (`docs/test-results/0182/hand-landmark-boxes.jpg`).
- AprilTags: none in view, so the tag path ran but `arm_tags` stayed empty; distance not checked.

## App step 3 (owner, 4 Nov: "Yes, step 3")

- LOCK sends `track_start` with the AI's box in pixels of the frame it sent to the AI
  (`lib/services/lock_tracking.dart`); UNLOCK sends `track_stop`. Old firmware ignores both.
- The green box over the video follows the detection that has a `track_id` (only the locked item has
  one); before the first one, and after the camera loses the item, it stays where it last was.
- The live scan and its quiz skip the tracked box, so LOCK still opens no quiz (0181); hands still
  reach it, so the arm pause is unchanged.
- A box more than 3x larger or smaller in area than the LOCK box counts as lost in the firmware
  (`TRACK_MAX_GROWTH`), and the app hides the green box 1.5 s after the last tracked box
  (`lockOverlayBox`).

### Phone tests (4 Nov, Motorola, debug APK, real MaixCAM2; owner's screen recordings)

- APK `4674d13`: LOCK boxed the pack ("Kardus"), and the box followed it. A hand lifting it from the top
  stretched the box to twice the height, the camera then lost it, and the phone kept drawing that
  stale box for 20 s. This led to the two fixes above.
- APK `478cb47`, firmware `5adb4417`: the box followed the pack while it stood, was pushed, and
  was lifted and carried up-left (20-35 s). At 36 s a fast lift with a twist lost it, and the box
  disappeared as intended. With the pack back in place there was no box until a new LOCK.
  The video read 10-12 fps while tracking and 16-21 fps otherwise
  (`docs/test-results/0182/phone-lock-follow-retest.jpg`).
- Firmware `ae18b046` (no give-up, whole-frame re-find after 5 misses): a lost pack came back in
  under a second (22.0 -> 22.7 s, 86.0 -> 86.7 s). Box size stays approximate after a flip or
  turn (half the pack, or too big): MixFormerV2 keeps the LOCK shape, it does not measure the
  outline.
- Firmware `763bef6c` (`steady()`: a box within 15 % shift and 30 % size of the last one is
  blended 25 %): the box sat still on a still pack (51-57 s, 116-119 s); a pack laid flat was
  lost and found again when stood up.
- Measured on the camera with the pack still (69 boxes, 15 s): centre x +-0.5 px, width +-1 px,
  centre y +-4.5 px, height +-7 px of 124. Owner: after LOCK a still item needs one fixed box;
  moving may bounce, settling must not bounce much. So `steady()` became `hold()`: within 10 %
  shift / 15 % size of the held box the held box is sent unchanged; beyond it the box follows at
  once; after 5 still calls (~1 s) it moves once to their median if that is more than 3 px away.
  The 3x size guard now compares with the previous box, not the LOCK box, so driving closer
  after LOCK is followed.
- Hold measured on the camera (68 boxes, 15 s, still pack): height range 14 -> 1 px, centre y
  9 -> 1 px; the box changed 4 times, 3 of them width re-settles of 4-5 px, so the settle step
  became 6 % of the box instead of 3 px.
- With the 6 % settle (firmware `ff9918e9`): 69 boxes in 15 s on a still pack, all exactly the
  same box (0 px change in x, y, w, h), score 0.998, 9.1 fps.
- Owner: a flipped item must not bounce either. A move now needs two calls in a row beyond 10 %
  shift or 30 % size of the held box (one odd box is ignored); smaller size changes, such as a
  flip in place, only go through the ~1 s median settle. A flipped-pack sequence gave 9 different
  boxes in 10 calls before, 2 now (one settle). Cost: a move shows one call (~0.2 s) later, and
  while the robot drives closer the size can lag up to 30 % until ~1 s after it stops.
- The item's name sits outside, on the box's top edge (owner); inside only when the box touches
  the top of the video.
- For an accurate pick box the plan is a fresh Gemini box once the item is still, before
  picking (not built).

## Not in this step

- The arm picking the tracked box (R1 still takes its target from the live scan's lock).
- A lost item is not found again by itself: the green box goes away and the user presses UNLOCK and
  LOCK again. No message says so yet.
- Calibration (`dist_cm`, `lateral_cm`, exact `dist_mm`).

## Tests

`firmware/maixcam2/test_clean_stream.py`: box validation, tracker init/follow/lose, landmark hand
boxes, tag ids and rough distance (no NaN on the wire), half-size tag search, and the real
`ws_frame_pusher` with fakes (one JPEG per frame, `clean_image` == `image`, held boxes). The new
tests fail on the old firmware (break-check). Wi-Fi and dashboard tests unchanged.

## Rollback

On the camera: `cp /root/main.py.pre-track.bak /maixapp/apps/elios_clean_m2c_v1/main.py` (and
`/root/app.yaml.pre-track.bak` to `app.yaml`), then close and reopen ELIOS Clean Vision.
