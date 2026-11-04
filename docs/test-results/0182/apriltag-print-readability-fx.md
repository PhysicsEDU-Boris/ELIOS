# 0182 Printed AprilTags: readability and focal length (4 Nov)

Camera firmware `9cd825b3` (live, unchanged). Printed sheet `docs/print/apriltags-arm-id0-id1-A4.pdf`.
Owner measured the black squares with a ruler: id 0 18.52 mm, id 1 6.17 mm. The tags were flat on
a white wall near the image centre, facing the lens, with the distance from lens to wall measured
by ruler. Over USB: `arm_tags` on, 6–8 s per station. Two numbers per run:

- the firmware's own detection rate (its 320x240 search);
- OpenCV `CORNER_REFINE_SUBPIX` on the 640x480 `clean_image` of the same frames.

## Focal length (id 0 alone, 150–300 mm)

| Ruler | Tag width, firmware | Live `dist_mm` (fx 375) | With fx 487 |
|---|---|---|---|
| 150 mm | 60.1 px | 115.5 | 150.1 |
| 200 mm | 45.5 px | 152.4 | 198.1 |
| 250 mm | 36.0 px | 192.7 | 250.5 |
| 300 mm | 30.0 px | 231.0 | 300.2 |

- **fx = 487 px** (fit through the origin on the firmware's tag widths).
- **Error:** within 2 mm from 150 to 300 mm.
- **The live guess is too short:** the firmware's nominal 81° guess, fx 375, reads 23 % short.
- **OpenCV comparison:** OpenCV's sub-pixel corners give 472–489 px, because they sit slightly
  inside the black square. The firmware formula should use 487.

## Readability, id 0 and id 1 side by side, room light

| Ruler | id 0 firmware | id 0 corrected dist | id 1 firmware | id 1 OpenCV full frame | id 1 width (search copy) | id 1 corrected dist |
|---|---|---|---|---|---|---|
| 100 mm | 99 % | 97 mm | 99 % | 100 % | 32 px (16) | 93 mm |
| 150 mm | 99 % | 150 mm | 98 % | 100 % | 21 px (10.5) | 142 mm |
| 200 mm | 99 % | 200 mm | **0 %** | **100 %** | 14.6 px (7) | – |

"Corrected" means fx 487 with the true sizes. The live firmware still sends id 1 with 10 mm, so
it reads 117 mm at 100 mm and 178 mm at 150 mm.

- **The firmware loses id 1 between 150 and 200 mm** (10.5 → 7 px in the 320x240 copy). The camera
  image is not the limit: OpenCV reads id 1 in every full-size frame at 200 mm.
- **A flashlight changed nothing.** With the flashlight on at 200 mm, image brightness was the same
  (mean 157, p5/p95 67/186) and the result was the same (id 1 0 % / 100 %). The flashlight does
  not help.
- **id 1 reads 5–7 % short.** At 20–30 px, one pixel of corner error is 3–5 % of distance, and
  the half-size search doubles that.
- **Where id 1 sits on the robot:** at the home pose in robotic_hand_sim, id 1 (arm3 rear) is
  about 60 mm from the lens. Its range in the poses where it faces the camera is not checked.

## Fix options (not built)

1. **Code:** `NOMINAL_FX` → measured 487 and `TAG_SIZES_MM[1]` 10.0 → 6.17. This is the
   distance fix; keep `dist_rough` because tilt and lens distortion are not modelled.
2. **id 1 past 150 mm:** search at full resolution inside a crop around id 1's last position. The
   whole 640x480 frame is not an option, because that kills the process. Alternatively, print
   id 1 larger if the arm3 rear face has room: a 15 mm print has a 9.3 mm black square, which
   reaches about 300 mm.

Photos: `apriltag-print-id0-150mm.jpg`, `apriltag-print-id0-id1-200mm.jpg`.
