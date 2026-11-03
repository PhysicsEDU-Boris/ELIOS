# 0012 — Identify the locked crop and confirm hazardous items (M2c)

Date: 2026-10-15. Supersedes the label-only identification boundary in 0008.

Status: Accepted (owner manual acceptance 16 Oct; hardware gaps listed in HANDOFF).

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
E_Waste classification cannot be downgraded by Gemma (amended by 0180: the AI may clear it with an
explicit organik/anorganik/residu bin and no hazard words in its item). The popup warns about
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

## Clean original pixels — 2026-10-16 (supersedes annotated crop input)

The copied exact Gemma inputs from the rebuilt app prove contamination:
`scan-1792088943399297-0`, `scan-1792088975920656-1`, and
`scan-1792089028005351-2` contain red masks and green box edges. All three
locked E_Waste and retained B3 despite Gemma returning ponsel/anorganik,
limbah cair/residu, and perangkat elektronik/scanner/anorganik respectively.
Correct recognition on one annotated input means the accuracy effect is not
established. These 01:29–01:30 WIB scans are distinct from the old 00:31 scan.

The complete deployable firmware is `firmware/maixcam2/main.py`, derived from
untracked Maixcam.txt; deployment and hash verification instructions accompany
it. It encodes a clean JPEG before any draw_seg_mask/draw_rect/draw_string,
then draws and encodes the existing preview. No attempt is made to remove
colors from already annotated pixels. Original appearance/background remain;
Flutter applies the same center-box crop geometry to the clean original.

Protocol 1 carries frame_id and detection_frame_id in the same message as
clean_image/clean_detections. Only current inference results with misses == 0
are eligible; cached or grace-held boxes remain preview-only. Clean JPEGs are
encoded/sent only on nonempty fresh inference frames, never on intervening
preview, empty or held-only frames. This keeps the established mask renderer
and costs one additional JPEG on those inference frames, shared across clients.
Legacy clients ignore the extra fields, but receive their bandwidth overhead.
A demand-driven image request is deferred unless hardware throughput warrants
that extra request/response and capture-retention complexity.

CapturedFrame retains preview bytes separately. Its transport factory validates
protocol, same-message dimensions and matching nonnegative integer IDs, parses
fresh detections and never caches a clean image from an earlier frame. Invalid
metadata/unsupported protocols preserve preview and suppress identification;
missing clean pixels at a lock show a firmware-update notice, not a Gemma call.
Preview-only messages have null scan detections; only a successful inference's
empty list means an empty scene. Old firmware retains preview/control and
label-only mode, but LIVE_SCAN identification requires clean-image firmware.
Device-photo identification is unchanged. Old apps still use annotated input.

The crop worker rejects absent/mismatched clean pixels and keeps generation
cancellation guards. E_Waste veto, hazard actions, single model slot, preview
subscriptions, score thresholds and anti-spam timers are unchanged. Lock
sampling is now at inference cadence; its hardware latency/FPS must be checked.
Firmware is responsible for original orientation and dimensions; receipt age
still cannot measure camera capture age. Frames have no hardware clock time.
A firmware SHA-256 is printed at startup, returned by ping, carried in frames
and logged at lock for subsequent deployment verification.

Timing evidence for session ...5351-2: identify 5.844 s, confirmation wait
10.369 s (resolved to Continue), question generation 5.562 s, question first
token 0.728 s, total lock-to-question 21.820 s. Total includes human wait and
must not be reported as generation latency. Crop took 41 ms.

Focused tests cover clean-versus-annotated pixels, image/frame pairing,
legacy rejection, malformed metadata, fresh-empty versus preview-only frames,
and the actual firmware push function's encode/draw order, cadence and held
box filtering. Break-checks restore annotated crop selection and move clean
encoding after drawing; both must fail, then be restored. Existing hazard,
cancellation and anti-spam tests remain required.

Deployment, exact clean robot-input JPEGs, annotated moving preview, isolated
phone/bottle accuracy and B3 disagreement are still owner hardware gates.
The stdout logging gap, PET contradiction and Q5 fallback are separate
follow-ups. No recognition prompt/quiz rewrite or threshold tuning is included.

## 16 Oct clean-stream failure investigation

The c438e94 LIVE_SCAN build launched at 10:25:01 WIB (PID 8194). Four
10:28–10:29 locks (sessions 1792121308094220-0, 1792121323937693-1,
1792121357069544-2, 1792121368294749-3) have null frame/detection IDs and
firmware hash, imageSource unavailable, and invalid crops before any Gemma
request. Receipt age is 0–2 ms; that is not camera capture freshness.
The warning means hasPairedCleanImage is false; its firmware-update wording
is not evidence of the running firmware version. Protocol-1 malformed IDs,
metadata or base64 suppress detections instead of producing these locks.
The inspected receive path therefore points to the legacy schema branch,
but raw packet metadata and the active firmware hash remain missing.
The intended source emits protocol/frame/hash metadata on every preview;
clean JPEG is added only for fresh nonempty inference. A direct metadata-only
probe timed out. No unsupported firmware/parser fix or validation bypass made.

The uploaded annotated JPEG 1792119881048431-0 is from 10:04:41 WIB,
before this launch, and cannot be assigned to the failed scans. The 23.8 s
recording shows failures at 00:09 and 00:21, with a boxed preview at 00:18;
10–12 fps counters do not prove preview continuity behind the opaque popup.
Next: capture the actual running startup hash and same-endpoint packet keys,
field types, byte counts and matching IDs (never base64 contents), then retest
one isolated phone. Deployment and clean-input hardware acceptance remain open.

## Owner clarification and clean-input acceptance evidence — 16 Oct 2026

The [latest review](../test-results/m2c-clean-image-review.md) supersedes the
pending clean-input evidence above: S4–S7 have annotation-free exact inputs,
matching frame IDs and the intended firmware hash. Lit phone/bottle recognition
and E_Waste confirmation before Continue/quiz are demonstrated. M2c remains
incomplete: cancellation/recovery, explicit Rescan/no late popup, continuous
visible 60-second hold, live preview during popups and owner TTS listening remain.
At recording 01:24 and 01:32 the owner deliberately covered the lens; red/noisy
imagery is NOT a firmware bug. Recovery occurred on uncovering. A clearer
recording is planned; lens covering alone does not prove an empty scene.

### Three-bin routing: intended policy versus inspected implementation

Hardware has organik, anorganik and B3 compartments only. Intended order:
use Gemma's category, apply B3 veto if any supported source raises hazard,
otherwise route residu to inorganic because there is no residu compartment.
Keep raw Gemma classification distinct from the resolved destination bin;
residu routed to inorganic is not thereby recyclable. S7 kertas/residu ->
Kertas/inorganic is an expected outcome, NOT a category-override failure.

Inspection: WasteQuizNotifier._identifyThenQuiz applies detector hazard via
categoryHint B3. ScannedWaste.fromLabel recognizes organik/anorganik/B3 and
preserves hazardous item keywords. However, residu is not explicitly mapped:
it falls through to _fromKeywords. S7 resolves inorganic through the kertas
keyword, not a general residu routing rule. A residu item with organic keywords
can resolve organic; one without recognized keywords can remain unclassified.
This differs from the owner's general policy and is a documented follow-up,
not authorization to change runtime behavior in this documentation task.
The existing inorganic categoryNameId also says "dapat didaur ulang"; that
wording must not be treated as a recyclability guarantee for the destination.
Raw identify_result.category and resolved.category already remain separate in
JSONL. No routing fallback, hazard veto or runtime code changed here.

Future quizzes must be strictly grounded in the course module students learned;
owner PDF pending, implementation deferred to the [quiz plan](../pipeline/README.md#module-grounded-quiz-plan-owner-requirement).
Duplicate/conflicting questions and Paper Q4 fallback remain separate follow-ups.
Paper Q4's 8273 ms is measured generation duration, not a verified timeout cause;
module context has not been shown to fix generation latency or fallback reliability.

## Explicit residu routing implemented — 16 Oct 2026

This supersedes the resolver discrepancy above. ScannedWaste.rawCategory retains
Gemma's supplied category unchanged; category remains the resolved destination.
The provider passes detector hazard separately as hazardousEvidence instead of
replacing the raw category with B3. Hazard from the detector, Gemma B3 category,
or existing item keywords wins first. Nonhazardous residu (case/space normalized
for routing only) explicitly maps to inorganic, regardless of item keywords.
Other recognized hints and unknown/missing-hint keyword fallback are unchanged.
Existing JSONL identify_result.category and resolved.category remain distinct.
For residu routed inorganic, categoryNameId describes residu and its compartment
without implying recyclability; other category descriptions remain unchanged.

Focused tests cover organic-sounding, inorganic-sounding and unknown residu
items; raw-category retention; keyword/detector hazard veto; other hint behavior;
and the provider's residu + E_Waste confirmation flow. Removing only the residu
mapping makes the organic/unknown tests fail, then restoring it passes. No
firmware, crop, cancellation, cooldown or module-ingestion change is included.
Robot acceptance gaps and the planned module-grounded quiz remain open.

## Three-bin policy and detector/Gemma mismatch gate — 16 Oct 2026 (owner)

Policy (canonical statement). The robot has three physical bins only:
organik, anorganik and B3. Order: Gemma's raw category; then the hazard veto
(detector E_Waste, Gemma B3 or a hazardous item keyword) to B3, which always
needs confirmation; then nonhazardous residu to the anorganik bin as a
hardware fallback, because there is no residu compartment. This is NOT a
claim that residu is scientifically anorganik or recyclable. Raw Gemma
category (`identify_result.category`, `ScannedWaste.rawCategory`) and the
resolved bin (`resolved.category`) stay separate in diagnostics.

Mismatch gate (929fdf4). Problem: on 16 Oct a laptop was detected as
Cardboard and Gemma said kardus/kertas/organik; with an E_Waste-only veto it
went to the organik quiz. Now the detector class's expected category
(Organic = organik; Paper, Paperboard, Cardboard, Plastic, Glass, Metal,
Tetra_Pak = anorganik; E_Waste = B3; Human_Hand ignored) is compared with
Gemma's RAW category; residu and anorganik are compatible. Any other
difference, including a missing Gemma category, is a mismatch.

On mismatch the session enters `confirmingMismatch`: no quiz is generated.
The card shows the detector class and Gemma's item and category, with
"Pakai detektor", "Pakai Gemma" or "Scan ulang". The quiz starts only after a
choice; "Pakai detektor" keeps Gemma's item name with the detector's bin.
Hazard wins: a hazard source shows the B3 card, never the mismatch card.
The app has no category-driven robot sorting path today, so nothing is sorted
before (or after) the choice; the arm stays under manual control.

Each mismatch is a hard example in JSONL: `category_mismatch` (appCommit,
frameId, detector label and score, raw Gemma item/category, Gemma-resolved
bin, detector bin, identify JPEG file name in the same directory), then
`mismatch_choice` (detector, gemma or rescan, with the final bin). Gemma's
output and the keyword lists are unchanged; there is no cardboard override.

Tests: Cardboard + organik shows the card with no question and logs the hard
example and choice; Cardboard + anorganik or residu shows no card; E_Waste +
anorganik shows the hazard card; Scan ulang leaves no late quiz; popup layout
has no overflow. Break-check: disabling the gate fails the first test.
Robot retest with the laptop is still required.

