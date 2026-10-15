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
