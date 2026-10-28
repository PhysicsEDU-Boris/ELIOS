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

## Owner Mac acceptance (2026-10-28, code 1b80900)

- NOT ready to merge: real PDF export throws `PdfTooBigPageException` for a roughly 840-word student essay; pending essay grading instead saves 5/10 (inherited fallback, violates 0031).
- Analyze and secret scan clean. Full suite: 489 passed, 3 failures (2 known splash tests plus TTS fixture still using old `active` phase).
- Extra acceptance: 3 passed (800x600 / 844x390 layouts; TTS advance from `explaining`), 2 failed (long PDF, unavailable grading).
- Existing schema-v1/v2, explanation save/reload, review expansion and short PDF tests pass. Sample PDF readable but has an extra blank trailing page.
- Combining with fixed G2c 31b86b7 conflicts in this handoff, scan_history_screen.dart and its test, and scan_record_store_test.dart. No merge/rebase performed.
- Native share/save and deliberate app quit/relaunch persistence remain unverified. No physical robot used. PR remains unmerged.

## Tests reported before acceptance (superseded above)

- `flutter analyze` 0 issues.
- `flutter test` 490+ passing (only 2 known-stale splash tests in `test/widget_test.dart` fail).
- `./scripts/check-secrets.sh` clean.
- Unit, widget, lifecycle, PDF, and persistence tests added and passing.

## Next

1. G2c (home/height reset & ee_mm status fixes).
2. Codex: L2 + L4 firmware in `firmware/maixcam2/main.py`.
3. L5 R1 student flow on screen, U7 Firebase (deferred), U8 docs.
