# 0183: Wide 16:9 camera stream (640x360) and measured focal length for arm tags

- Status: Accepted (owner chose 16:9, 4 Nov). Code and tests only; not deployed to the camera.
- Builds on: [0182](0182-camera-tracks-lock-box.md) (tracker, hands, `arm_tags`), [0022](0022-detection-protocol-distance-tags.md).
- Tests: [apriltag-print-readability-fx.md](../test-results/0182/apriltag-print-readability-fx.md).

## Context

- **The 4:3 stream is a crop.** The MaixCAM2 streamed 640x480. A ruler test with the printed
  id 0 tag (150–300 mm) gave fx 487 px, so that view is only 67° x 52°. The lens spec, and
  robotic_hand_sim's camera, are 81° x 51°.
- **Firmware distances were 23 % short.** The firmware's `dist_mm` used a nominal fx of 375, and
  id 1 was set as 10 mm. id 1 is a 10 mm print, so its black square is 6.17 mm.
- **Which mode is the wide view.** Three photos at the same distance from a standalone script
  (the app was closed and its files untouched) show which camera mode gives the wide view:

| Mode | Tag width | fx | View (H x V) |
|---|---|---|---|
| 640x480 | 29.9 px | 487 (ruler) | 67° x 52° (crop) |
| **640x360** | 22.2 px | **362** | **83° x 53° (full sensor)** |
| 1280x720 | 78.6 px | 1280 | 53° x 31° (centre crop) |

1920x1080 did not save.

## Decision (owner: "alright i choose 16:9")

- **Stream size.** `STREAM_RESOLUTION = (640, 360)`, the full wide view, matching the sim.
  1280x720 is not used, because it is a narrower crop.
- **Focal length.** `CAMERA_FX = 362` replaces `NOMINAL_FX` (375). This is the ruler fx scaled by
  the tag-width ratio. `dist_rough` stays true, because the principal point and lens distortion
  are not measured yet.
- **Tag sizes.** `TAG_SIZES_MM = {0: 18.52, 1: 6.17}`, as the owner measured with a ruler.
- **Tag search.** The search runs on a 320x180 copy (`TAG_SCALE` 2; a full frame still kills
  `find_apriltags`).

## Consequences

- **Wider view.** About 12 cm wider at 30 cm, so hands at the sides are seen sooner and a locked
  item stays in view longer. The sim's camera and ground truth fit the stream after a pixel rescale.
- **Smaller objects.** Everything is 26 % smaller in pixels than at 640x480. id 1 is expected to
  be found only to about 110 mm, measured 150 mm at 640x480. id 0 is expected to about 220 mm or
  more. Gemini's `clean_image` is 640x360. All of this is untested at 640x360.
- **Fewer pixels.** 25 % fewer pixels per frame (JPEG, hands, tags), so fps may rise a little.
  Not measured.
- **App.** The app reads `img_w`/`img_h`, and the phone layout places the lock box for any
  aspect. The tablet portrait layout's fixed 4:3 box crops the sides of the 16:9 frame (cover);
  no code change.
- **Next.**
  1. Deploy with the owner's OK, backing up the live `main.py`.
  2. Re-check tag range and fps.
  3. Run the ChArUco board solve (`docs/print/maixcam2-calibration-board-charuco-A4.pdf`) at
     640x360 for fx, fy, cx, cy and distortion. That replaces `CAMERA_FX` and gives the sim its
     camera model.
