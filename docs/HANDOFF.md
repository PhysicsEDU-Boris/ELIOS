# Handoff

- Branch `feat/u4-quiz-explanation-pdf` (base `58fd087`, origin/feature/live-scan).
- PR open against `feature/live-scan`.

## Done (U4 Quiz Explanations, History & PDF)

- Lifecycle: `Question -> Answer submitted -> Result -> Detailed explanation -> Next question`.
- MCQ overlay (Figma 96:130) with success/error banners, comparison table, takeaway, and chat.
- Essay overlay (Figma 96:246) with score, rubric breakdown table, and suggestions.
- Persistent local schema v2 (`RecordQuestion.explanation`, `ScanRecord.schemaVersion`).
- History (Figma 100:170) inline "Lihat Penjelasan" expand toggle, "Tersimpan lokal" status.
- `QuizPdfService` generates and shares multi-page A4 PDF reports (result card & history).
- Decision [0031](decisions/0031-quiz-explanation-pdf.md).

## Tests

- `flutter analyze` 0 issues.
- `flutter test` 490+ passing (only 2 known-stale splash tests in `test/widget_test.dart` fail).
- `./scripts/check-secrets.sh` clean.
- Unit, widget, lifecycle, PDF, and persistence tests added and passing.

## Next

1. G2c (home/height reset & ee_mm status fixes).
2. Codex: L2 + L4 firmware in `firmware/maixcam2/main.py`.
3. L5 R1 student flow on screen, U7 Firebase (deferred), U8 docs.
