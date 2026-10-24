# 0025: In a live scan the detector class picks the bank questions (B1)

- Status: Accepted
- Date: 2026-10-24
- Amends: [0017](0017-object-bank.md) (object bank) and [0015](0015-question-bank-draft.md) (label pools).
- Code:
  - `lib/models/scanned_waste.dart` (`detectorLabel`);
  - `lib/services/question_bank.dart` (`selection`, `classMismatch`);
  - `lib/providers/waste_quiz_provider.dart` (`_logClassMismatch`, the `detector=` field in
    `question_source`);
  - `lib/services/gemma_quiz_service.dart` (`questionPrompt`);
  - `lib/widgets/live_scan_debug_overlay.dart` (scan line).
- Tests: `test/bank_detector_class_test.dart`, `test/m2c_identification_test.dart`.

## Why

On 24 Oct, with the fake MaixCAM2 in bank mode:

- The detector labelled a box Plastic (0.85).
- Gemma identified the crop as just "Label" (material kertas).
- The bank served a paper question ("Kertas bekas dapat terurai karena berasal dari apa?").
- The same card had earlier read "Label plastik" and got a plastic question.

**Cause.** `poolFor` meant to use "the detector class when known", via `scan.rawLabel`. But in
the live scan the scan is built from Gemma's item, so `rawLabel` held Gemma's text, and the
detector class never reached the bank. With no object match, the pool came from Gemma's words.

The mismatch card (`categoryMismatch`) compares bins only, and Plastic and paper are both
anorganik, so nothing showed it.

## Rule

`ScannedWaste.detectorLabel` carries the detector class of the locked box. It is set in the live
scan and kept when the user picks "use detector" on the mismatch card. `rawLabel` stays Gemma's
text.

The detector class **decides** when it has a label pool and its bin is the scan's resolved bin.
It does not decide for the phone camera, a manual scan, or a scan whose bin the user switched
to Gemma's on the mismatch card. That also keeps B3 and non-B3 apart, both ways.

Bank selection:

1. **The object Gemma's words match**, used only if the object's `label` equals the deciding
   class, or no class decides.
2. **Else the deciding class's label pool.**
3. **With no deciding class:** the fallback from before this decision (the raw label's pool,
   then the bin, then the item/material words).

A B3 object still never serves a non-B3 scan, and the reverse (unchanged).

**Same bin, different class:** when Gemma's words point to another pool than the deciding class
(a Plastic box, Gemma "kertas"):

- a `class_mismatch` event is logged once per session, with `detectorLabel`, `gemmaItem`,
  `gemmaMaterial`, `gemmaPool` and `chosenPool`;
- **no card is shown**: the bin is the same, so the sorting is right, and the detector class
  decides the questions.

Classes that share a pool (Paper, Paperboard and Cardboard all map to `paper_family`) never
count as a mismatch.

Consequences:

- An object with no detector `label` (lampu TL/CFL) is no longer served on an E_Waste box. Those
  scans get the `e_waste_b3` pool.
- Without a detector class, everything is as before.

## Gemma mode

The question prompt already carries a category hint (`kategori: ...`). Next to it, it now says
`menurut detektor kamera: <class>` (the Indonesian class name), as context only. The question
text, the angle rule (0019) and the source rules (0018) are unchanged.

## Visible to a tester

- The quiz chip "Terdeteksi: ..." still shows Gemma's item.
- The live-scan debug overlay adds a line: `gemma "<item>"   detektor <class>`.
- Every `question_source` log line carries `detector=`, and its `object=` and `pool=` are the ones
  actually served.
