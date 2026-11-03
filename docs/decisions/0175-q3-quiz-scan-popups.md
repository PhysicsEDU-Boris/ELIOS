# 0175 Q3: one R3 quiz popup everywhere, real explanation data, loading and skeleton, R3 phone camera scan

Status: Draft (3 Nov 2026). On top of 0174 (R3), 0031 (explanations, pending essay grades), 0013 (MC schema), 0041/0070 (crop).
Figma J2jSbARJSyJCStNFeWkWDj, page 393:2358 (frames listed in docs/test-results/q3/README.md).

## Decision
- **One popup.** `WasteQuizPopup` renders the shared R3 widgets (`lib/widgets/quiz/quiz_r3.dart`, a part of the popup library)
  in Control (phone and R2), the phone camera scan, tablets and the Mac (centred, max 1100x720). `phone_quiz.dart` is gone.
  `WasteQuizUiState` and the phases are unchanged. Not in Figma, restyled into the same shell: essay input, "Not this?"
  (Bukan ini) picker, hazard and mismatch confirms. The finished result card is the older card inside the shell.
- **Review.** No logo in the review headers; the coach shows the ELIOS leaf. Banners: right = happy bottle + gold +10;
  wrong = "Not quite", the right answer, sad bottle, locked medal, grey +0; essay = bulb + Score n/10; pending (0031) = grey
  "Waiting for grading", +0. Left: the scrolling document (answer check, explanation, quote, Table 1, takeaway, source chip).
- **Data, no invented text.** The bank's `quote`, `sourceChunk`, `pdfPage` and `id` go through `GeneratedQuestion` into
  `QuizExplanation` (`sourceSection`, `sourcePage`, new `quote`, `bankId`); essays use their rubric points' quotes and pages.
  `comparisonRows` only on a right answer; a wrong answer gets the options table. "Why your answer is not right" shows only a
  reviewed `wrongWhy` (optional bank field: an object from wrong option text to reason, so the 0013 shape stays valid); none
  are written, so the heading stays hidden. The generic wrong-answer and concept sentences are gone. `ScanRecord.schemaVersion`
  is 3; old records load. History and the PDF show the quote and "Sumber · bagian · hal. · id".
- **Loading.** Shown for identify and question preparation with a real elapsed timer (`WasteQuizNotifier.loadingSince`),
  an indeterminate bar and three steps tied to real state: scan read (identify done), topic or bank pool picked (generation
  started), question being written. "Answer key checked" is dropped: parsing/validation is not a separate event.
  Minimise → Quiz button Waiting; when the question arrives while minimised the badge shows and, with Voice on, TTS says
  "Question ready". The skeleton shows while a camera photo is taken and cropped, and whenever the quiz has no question yet.
  STOP stays real in both.
- **Camera scan.** R3 layout (ready, model loading from the real `GemmaStatus`, skeleton while the camera starts). Percent only
  while installing (the only stage that reports progress). Scan is disabled while the model is idle/loading/installing/paused;
  missing, error or killed models scan in bank mode as before. The identify crop is unchanged: the preview keeps the old panel
  (screen minus 240 dp) and the corners mark the crop, so they are not centred in the R3 video card. Test mode (debug only)
  replaces "Uji tanpa kamera". The Quiz button sits in the top bar.
- **Test builds.** `SCAN_RECORDS_FILE` builds keep History photos in `scans_<file>/`, not the shared `scans/`.

## Owner questions
Who writes the 126 `wrongWhy` texts? Should the R2 tablet/Mac layout also get GO and the logo removal?
