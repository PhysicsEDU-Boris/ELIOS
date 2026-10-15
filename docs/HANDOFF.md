# Handoff

- Branch `feat/m2c-crop-identify`; investigation based on local `383e448`.
- M2c NOT complete; documentation only; no reset, push, merge or code fix.

## Evidence — 2026-10-16

- Exact Gemma input JPEG/JSONL NOT FOUND in accessible app-support/container
  locations or repo, including an escalated search. Some unrelated macOS
  directories deny access. `com.boris.elio` support/container paths are absent.
- Missing: `m2c-diagnostics/scan-<id>-identify.jpg` and matching `.jsonl`.
  Request ID, raw item/category, input overlays and receipt age cannot yet
  be correlated. Owner must supply pair or full `[M2c]` path from test device;
  confirm diagnostic build 383e448 was rebuilt/launched for that test.
- Recording: `/Users/macbookairm12020/Desktop/Screen Recording 2026-10-16 at 00.31.53.mov`.
  /watch local/no audio: `/private/tmp/watch-ej7u61xg/frames/` (8), `/private/tmp/watch-vbxwsyzs/frames/` (4 cues).
- 00:04 red-covered upright object, E_Waste 44%; 00:05 Cardboard 76% while
  Looking opens; 00:16 Wadah kemasan merah, generating; 00:23 quiz describes
  plastik anorganik, overlay total 16940 ms / question first token 284 ms.
  00:39 Cardboard 80%; 00:47 E_Waste 83% after moving/flipping the object.
- Owner identifies object as phone; video shows changing detector labels.
  Preview pixels cannot establish model-input pixels or raw JSON category.
  No B3-veto failure established: visible lock is Cardboard, not E_Waste.

## Provenance / hypothesis

- Local untracked Maixcam.txt: capture (589) → inference/decode (601–603) →
  draw_seg_mask (655), draw_rect (656), draw_string (657) mutate same frame →
  JPEG encode (668) → base64 JSON image/detections (672–677). No clean image.
  Source proves annotated transport in this reference; deployed version unknown.
- Flutter decodes transport bytes, retains same-message frame at lock, scales
  center XYWH to decoded pixels, clips/re-encodes crop, passes Message.withImage.
  Flutter CustomPaint boxes/labels/gradient/badges are display-only; no capture
  of the widget enters Gemma. Firmware-drawn content would survive cropping.
- Freshness: firmware reuses detections between cycles and briefly holds misses;
  receipt time is not capture/detection time; no source frame ID.
  JPEG decoder honors EXIF; boxes are not rotated. Neither explains this run yet.
- Contamination of this request and causal effect on recognition remain unproven.

## Proposed upstream path — not implemented

- If saved input confirms overlays: encode clean original pixels BEFORE drawing;
  keep existing annotated image for preview; add clean_image with same dimensions
  and frame ID in the same message. Crop clean_image with corresponding detection
  geometry; never recolor/remove red or substitute annotated pixels as fallback.
- Preserve detection-frame identity/freshness explicitly; compare paired crops
  from one original capture and identical geometry. Verify actual firmware first.
- Run 3 clean + 3 annotated trials per phone/bottle, same model/prompt/settings;
  record item/category, request IDs and latency. No paired originals available
  yet, so this comparison and isolated-phone/bottle retests are NOT TESTED.

## Checks / remaining owner tests

- Analyze clean; full tests 221 pass, only 2 known stale splash failures.
  Secret scan clean; no code changes or new break-check. PET/Q5 stay separate.
- Rebuild debug LIVE_SCAN, launch with open, then provide saved JPEG/JSONL pair.
- Pending: E_Waste disagreement still B3; Continue → quiz; close Looking → no
  late popup + later scan; wait 15 s then >=2 s empty re-arm; 60 s one-item hold;
  expose/move preview during identify/confirmation/quiz; TTS separately by owner.
