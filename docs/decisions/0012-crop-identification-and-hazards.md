# 0012 — Identify the locked crop and confirm hazardous items (M2c)

Date: 2026-10-15. Supersedes the label-only identification boundary in 0008.

## Decision

With `LIVE_SCAN=true`, a stabilizer lock passes its complete detection to
ControlScreen. The screen passes that box and the same CapturedFrame to
WasteQuizNotifier. The popup enters `identifying` immediately and displays
“Looking…”. Camera streaming, lock filtering, cooldowns and same-label
suppression continue as before. A lock causes only one identify request.

`cropDetection` decodes the JPEG, scales center-format box coordinates from
stream metadata to decoded dimensions, clamps to image edges, and encodes
only the crop. It runs through Flutter `compute`, once per lock. Invalid
metadata, empty/off-image boxes and undecodable images return no crop.
There is no full-frame or detector-label fallback on identification failure.

Gemma's existing unbiased `identifyItem` prompt supplies the item, material
and category used for questions. Non-string JSON fields are rejected or
ignored instead of throwing. Live scan warms up with `vision: true` so the
first crop does not require switching from a text-only loaded model.

If either the detector or Gemma/keyword classification says hazardous, the
session enters `confirmingHazard` before any question generation. A detector
E_Waste classification cannot be downgraded by Gemma. The popup warns about
B3 handling and offers “Lanjut kuis” (generate question 1) or “Scan ulang”
(dismiss). Label-only and device-photo sessions use the same confirmation.
Confirmation acknowledges continuing an educational quiz; it does not
operate the robot or certify the object's safety.

ASKING remains frozen through identification and hazard confirmation.
Identification failure reports a failed ask, without question timings.
Dismissal invalidates the generation before cancelling Gemma; late crop or
identify results are discarded. Existing re-arm rules apply after dismissal.

## Detector mapping (exact firmware spellings)

| Class | Display | Category |
|---|---|---|
| Cardboard | Kardus | inorganic |
| E_Waste | Sampah elektronik | hazardous |
| Glass | Kaca | inorganic |
| Human_Hand | Tangan | none; ignored by live scan |
| Metal | Logam | inorganic |
| Organic | Sampah organik | organic |
| Paper | Kertas | inorganic |
| Paperboard | Karton | inorganic |
| Plastic | Plastik | inorganic |
| Tetra_Pak | Karton minuman berlapis | inorganic |

The mappings describe broad waste categories; recycling acceptance still
varies by material and local collection facilities. Other/free-text labels
continue through the existing keyword lookup. The firmware class list was
checked against the local Maixcam.txt; that untracked file is not committed.

## Validation

Tests cover all classes, scaled/clamped/invalid crops, one crop request per
lock, identified item/material, both sources of hazardous classification,
confirmation before generation, label-only hazards, dismissal, failure,
malformed JSON, Looking text and responsive confirmation layouts.
Break-checks restored full-frame input, keyword-only mapping, immediate quiz
generation, old identifying text and the old JSON cast: each test failed,
then the fixes were restored. Existing scripted real-Gemma integration test
adapts to the detection callback but remains label-only, not robot validation.

Robot validation remains required: vision memory/latency, crop accuracy and
model recognition cannot be established by the mock-driven unit tests.

## Diagnostic follow-up — 2026-10-16

Inspection of 606be86: WebSocketService pairs image/detections from one JSON
message. ControlScreen updates `_latestFrame` then invokes the stabilizer
synchronously; its lock uses the current target, and compute retains that
CapturedFrame even as later frames arrive. Coordinates are center XYWH in
metadata pixels, independently scaled on X/Y to decoded dimensions; floor
left/top, ceil right/bottom, clamp to bounds. No preview/widget coordinates
enter the crop. Message.withImage receives those JPEG bytes unchanged.

This does not prove camera-time alignment. Timestamp is local receipt time;
no capture/detection timestamp or source frame ID is supplied. Dimensions
are cached when omitted by firmware. The untracked local firmware reference
(not verified as the deployed version) sends cached detections between
inference cycles, retains missed detections briefly, and burns masks/boxes
into the JPEG before sending it. These are input-quality/freshness risks.
The image package applies JPEG EXIF orientation while decoding; the crop
adds no box rotation. Rotated metadata axes remain an unverified risk.
No app crop/vision-path bug was established; geometry, prompt, cancellation,
B3 gating, preview, single-slot scheduling and cooldown thresholds stay intact.

Debug robot sessions now save `scan-<id>-identify.jpg` at the actual
Message.withImage call boundary, plus `scan-<id>.jsonl`, under
`getApplicationSupportDirectory()/m2c-diagnostics/`. The full image path is
printed with `[M2c]`. No upload occurs. Writes are queued without awaiting
inference; write/encoding failures cannot stop a scan. Artifacts persist
until the owner deletes that directory and are ignored if copied into git.
Mock tests emit `vision_mock`, not `vision_submit`; saved pixels prove app
request input, not native encoder tensors. Abrupt exit may lose queued writes.

Logs correlate session/request IDs, receipt age, unknown source timestamps,
label/confidence, metadata/decoded sizes, original center box, scale/clipped
crop bounds and size, raw identification JSON, resolved category/hazard,
dismissal and stale results. Crop timing includes compute overhead. Identify
request/first-token/completion timing includes readiness/stop waits;
`vision_submit` distinguishes actual submission from request start. Question
and prefetch timings include parsing/retries, with retry/fallback markers.
Total lock-to-question includes identification and any B3 human wait. The
existing overlay's 12.417 s is that total, not identify time; its first-token
number refers to question generation. Provider timing starts at lock handling
and ends when question state is published, not when pixels finish painting.

Recording evidence supplied by owner: bottle identified as Botol minuman,
relevant quiz in 12.417 s; phone detector E_Waste but item Barang plastik merah,
with B3 preserved; Rescan stayed dismissed ~18 s; bottle suppressed for 30 s.
Exact crop was not saved then, so model recognition versus contaminated or
misaligned input remains unresolved. Next: isolated stationary phone, compare
saved crop to physical phone and JSON; if crop clearly contains the phone,
repeat with orientation/lighting controlled. A clean-versus-overlay image
comparison is the next experiment if overlays obscure the object.

Pending owner acceptance: Continue actually opens quiz; close during Looking
has no late popup and a later scan works; 15 s cooldown then >=2 s empty scene
re-arms; 60 s hold has only one identification/quiz; visibly moving preview
during identify, confirmation and quiz. TTS requires a separate audio check.
PET/anorganik contradictory premise and Q5's 7.048 s wait/fallback are separate
quiz follow-ups; neither cause was established and neither is rewritten here.
