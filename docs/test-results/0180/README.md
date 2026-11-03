# 0180 B: Gemini box on lock, phone test (3 Nov 2026)

Phone: Motorola Edge 60 Fusion, debug APK `760d639` with `SCAN_RECORDS_FILE=scan_records_boxtest.json`
(the owner's History untouched; the file was never written). The real MaixCAM2 was offline
(nothing on port 8765 on WIFIBOR), so the fake MaixCAM (`tools/fake_maixcam`, real dataset photos
as clean frames) ran over `adb reverse`. Backend: the deployed `ai-backend` (no change).

| Run | Object | Sent photo | Result |
|---|---|---|---|
| 1 | Plastic (two_items) | padded crop | HTTP 503 after 25 s: every chain model 503 or timeout (Vercel log; no 400) |
| 2 | Metal can (two_items) | 192x288, 44 KB, can with room around it | HTTP 503 after 31 s, same |
| 3 | Plastic bottle (one_Plastic) | 232x362, 57 KB | `gemini-3.5-flash-lite`, 2.7 s, item "botol plastik PET", `box_2d` [226, 219, 810, 786], re-crop valid |

`gemini-box-vs-camera-box.png`: run 3's sent photo; red = the camera's box, green = Gemini's box.
Gemini's box is on the bottle and tighter (drops the background strips on both sides); the hand at
the bottom is still partly inside, and the top edge touches the cap (the 5 % crop margin covers it).

Not shown: the real ELIOS camera, more objects, latency over many calls (one 2.7 s answer vs ~1.6 s
for identify without the box on 3 Nov; one sample, not a measurement).
