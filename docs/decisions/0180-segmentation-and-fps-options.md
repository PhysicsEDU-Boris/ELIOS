# 0180: Better segmentation and a faster ELIOS camera: options

- Status: Accepted for option B (owner, 3 Nov 2026: "we try Gemini"); FPS steps and A/C still open
- Date: 2026-11-03
- Builds on: [0012](0012-crop-identification-and-hazards.md) (lock → one crop → identify),
  [0025](0025-bank-detector-class.md) (detector class picks the bank pool),
  [0179](0179-gemini-cloud-ai.md) (Gemini through `ai-backend`).

## Owner's question

"My trained model's results are not good enough. Can I use segmentation from another AI API with
better precision, together with the Gemini system? Is SAM 3 free? Other options? And I want a
higher camera FPS."

## What ELIOS does today (`firmware/maixcam2/main.py`, app live scan)

- **Model:** the owner's YOLO11-seg, 10 classes (Cardboard, E_Waste, Glass, Human_Hand, Metal,
  Organic, Paper, Paperboard, Plastic, Tetra_Pak), 640×640 input, on the MaixCAM2 NPU.
- **One loop, one thread** (`ws_frame_pusher`): read camera at 640×640 → every 2nd frame: NPU
  forward + decode in numpy on the CPU (DFL softmax over 64×8400, sigmoid 10×8400, NMS, mask
  matmul per box) → draw masks/boxes → JPEG → base64 → `json.dumps` → send to every client. A
  second JPEG (`clean_image`) goes out on detection frames that have a box. `dual_buff=False`.
- **Measured rate:** 13–14 fps video, 4–7 fps analysed frames (0178, HANDOFF, 0012 notes).
- **Already a hybrid:** the camera only finds and locks the box. The app crops that box from the
  clean frame and Gemini names the item (0012/0179). The detector class still picks the bank pool
  and the E_Waste hazard (0025), and a missed or wrong box means no crop at all.

So "precision" problems show up as: wrong or missing boxes (no lock, or a lock on the wrong thing),
loose boxes (crop includes background), and a wrong class (wrong bank pool / hazard).

## Where the time goes (estimate; the camera was off, not measured)

At 13–14 fps one frame costs about 70 ms. The NPU is not the limit: Sipeed rates YOLO11n at about
113 fps and YOLO11s at about 62 fps at 640×640 (detection; seg is somewhat slower). Most likely the
time goes to Python/numpy on the CPU: the full-grid decode (softmax over all 8400 anchors before
the score filter), the per-box mask resize, JPEG encode (twice on detection frames), base64 (+33 %
bytes) and JSON of a ~50–80 KB string, all in series in one loop. Wi-Fi (~14 × 60 KB ≈ 7 Mbit/s)
is fine on a good 2.4 GHz link but adds jitter on a phone hotspot.

**Step zero:** add one timing log line per stage (firmware change, needs the owner's OK) and read
it for 30 s. Fix the biggest stage first.

## FPS options (all need a firmware change; none needs a paid service)

| # | Change | Expected gain | Precision cost | Effort |
|---|---|---|---|---|
| F1 | Decode: filter by class score first, run the DFL softmax only on the few kept anchors | Large on detection frames (CPU work ÷ ~100) | None (same maths) | Small |
| F2 | Run NPU + decode in a second thread (or `dual_buff=True`) so video never waits for the model | Video fps ≈ JPEG+send rate (~20–30 fps likely) | Overlay lags video by one cycle | Medium |
| F3 | Binary WebSocket frames (JPEG bytes + small JSON header) instead of base64 in JSON | ~25 % fewer bytes, less CPU both ends | None | Medium (firmware + app parser, keep `vision_protocol` versioned) |
| F4 | Lower JPEG quality (e.g. 60–70) for the preview only; keep `clean_image` at full quality | Smaller frames, faster encode | None for identify (clean image unchanged) | Small |
| F5 | 5 GHz / a closer AP; avoid the phone hotspot for demos | Steadier fps, fewer stalls | None | None (setup) |
| F6 | Model input 320×320 or YOLO11n instead of s | ~4× less NPU work | Worse on small or far items | Retrain + convert |

Cloud segmentation **per frame** would lower FPS (each call is ~1 s or more round trip), so the
cloud is only for once-per-lock work.

## Precision options

| Option | Precision | Latency | FPS impact | Cost on free tier | Privacy | Effort |
|---|---|---|---|---|---|---|
| **A. Improve own model**: more photos from the ELIOS camera itself (its lens, light, table), hard negatives (empty table, hands), fix labels, try YOLO11s-seg | Best long-term fit for these 10 classes; depends on data | Unchanged (on device) | None, or small if bigger model | Free | Images stay local | Medium: label + retrain + convert |
| **A+. Use SAM 3 offline as a labelling tool** for A (text prompt "plastic bottle" → masks, owner reviews) | Better labels → better model | n/a (offline) | None | Free if run on a free Colab GPU (not tested) or Roboflow's labeller (free tier limits apply) | Training photos leave the device | Small–medium |
| **B. Gemini box on lock**: the existing identify call also returns `box_2d` of the main item in the clean frame; app re-crops / rejects "nothing there" | Good boxes, label already Gemini's; masks weaker and inconsistent across models | +0 s if folded into the existing call (~1.5 s) | None | Free key, same daily quota (~1,060 calls/day) | Frame already goes to Google | Small (prompt + parser + test) |
| **C. SAM 3 hosted (fal.ai)** on lock, text prompt = Gemini's item name | Best pixel masks of the options | ~1 s+ per call (not measured) | None if once per lock | **Not free:** $0.005 per image (~200 per $1) | Frame goes to fal (US) | Medium: new paid key in `ai-backend` |
| D. SAM 3 self-hosted | Same as C | ~30 ms on an H200 + network | None | Not free: needs a CUDA GPU server | Own server | Large |
| E. SAM 3 on MaixCAM2 or the phone | — | — | — | — | — | Not practical: 848M parameters, gated weights, CUDA/PyTorch reference code |
| F. Roboflow Serverless (SAM 3, RF-DETR) | Good | ~1 s | None if once per lock | Free Core tier is ~10 credits; then paid per image | Frame goes to Roboflow | Medium |
| G. Grounding DINO / OWLv2 (open vocabulary boxes) | Boxes only, below SAM 3 | Needs a GPU host | None if once per lock | No free host verified | Depends on host | Medium–large |

**SAM 3 facts (checked 3 Nov 2026):** licence is Meta's custom "SAM License", royalty-free and
allows commercial and educational use, with bans on military/weapons/ITAR uses and sanctioned
parties; anyone you pass the model to must get the licence; Meta may change the terms. Weights are
free but gated on Hugging Face (access request can be refused). SAM 3.1 (Mar 2026) is faster for
multi-object video. So: **the model is free; running it is not** (GPU or a paid API).

## Recommendation (draft)

1. **FPS first, free:** owner OK for a firmware change → timing line → F1 + F4 (small, no
   precision cost), re-measure; then F2/F3 if still below ~20 fps. F5 for demos.
2. **Precision, free:** B now (Gemini returns a box with the identify answer; the app tightens the
   crop and drops locks Gemini says are empty or hands). Keep the on-camera detector for lock and
   tracking.
3. **Precision, long-term:** A with A+ (SAM 3 as an offline labelling helper to build a better
   dataset from ELIOS's own camera), retrain YOLO11s-seg.
4. **Paid, only if the arm needs pixel-exact masks:** C (SAM 3 on fal, ~$0.005 per lock), called
   from `ai-backend` once per lock.

## Built: option B (3 Nov 2026)

- `prepareDetectionCrop` also makes `identifyBytes`: the locked box plus 25 % of its size on each
  side, so Gemini can see an object the camera's box cut off. The popup and History crops are
  unchanged when Gemini gives no box.
- `identifyItem` asks, in the same single call, for `box_2d` ([ymin, xmin, ymax, xmax], 0-1000) of
  the main item, and says hands are not the item. `parseBox` rejects missing, malformed and sliver
  boxes (< 5 % of a side); out-of-range values are clamped.
- Live scan only: a valid box re-crops that padded photo (`cropToBox`, 5 % margin), and the result
  becomes the popup crop and the History photo. The phone-camera scan ignores the box.
- No backend change (`ai-backend` passes the prompt through), no extra call, no firmware change.
  The detector still locks, picks the bank pool and flags E_Waste (0025).
- Tests: `test/m2c_identification_test.dart` (padded identify crop, Gemini box re-crop for popup and
  History, `parseBox`); the re-crop test was break-checked.
- Phone test (fake MaixCAM, real photos; [results](../test-results/0180/README.md)): one answer,
  3.5 Flash-Lite in 2.7 s, box on the bottle and tighter than the camera's. Two other runs got
  HTTP 503 from every Gemini model (Google overload, not this change).
- Real camera, one object: a cardboard box the detector called E_Waste (0.80); Gemini said "kardus"
  and its box matched the camera's. The label, not the box, was wrong, and the 0012 hazard rule then
  showed "Possibly hazardous (B3): Kardus". Gemini took 23 s (overloaded models skipped).
- Still open: more objects; latency when Gemini is not overloaded; whether Gemini may downgrade a
  detector E_Waste (owner question below).

## Questions for the owner

0. Should a confident Gemini answer be allowed to clear a detector E_Waste (today it never can,
   0012), or should the card just say both opinions?

1. May we change the camera firmware (timing line, then F1/F4)? It would be tested on the robot
   with the old `main.py` kept as a backup.
2. What goes wrong most: no lock, lock on the wrong thing, loose box, or wrong class? (Decides A vs B.)
3. Does the arm need a pixel mask (grip point / size), or is a tight box enough? (Decides whether C
   is worth paying for.)
4. Is ~$0.005 per scan for SAM 3 acceptable later, or must everything stay free?
5. Can you share the training dataset (size per class, source of photos)? Photos from ELIOS's own
   camera are the cheapest precision win.

## Sources

- SAM 3 repo and licence: https://github.com/facebookresearch/sam3
- SAM 3 licence summary: https://roboflow.com/model-licenses/segment-anything-3
- fal SAM 3 price: https://fal.ai/models/fal-ai/sam-3/image
- Roboflow per-image pricing and free tier: https://blog.roboflow.com/making-it-easier-cheaper-to-deploy-with-roboflow/
- MaixCAM2 YOLO11 speeds: https://wiki.sipeed.com/hardware/en/maixcam/maixcam2.html
- Gemini boxes and masks: https://ai.google.dev/gemini-api/docs/image-understanding
- SAM 3 speed claim (secondary): https://latent.space/reading/sam3-eyes-for-ai/
