# 0031: Quiz Explanation Overlays, Local Review History, and PDF Export (U4)

- Status: Accepted
- Date: 2026-10-28
- Covers: Figma file `J2jSbARJSyJCStNFeWkWDj` nodes `96:130` (Quiz Explanation Overlay), `96:246` (Essay Explanation Overlay), `100:170` (History Overlay).
- Code:
  - `lib/models/quiz_explanation.dart`: `QuizExplanation`, `ComparisonRow`, `RubricRow`, `GroundingStatus`.
  - `lib/models/scan_record.dart`: `RecordQuestion.explanation`, `ScanRecord.schemaVersion`.
  - `lib/services/quiz_explanation_service.dart`: deterministic and grounded educational explanation generation.
  - `lib/services/quiz_pdf_service.dart`: multi-page A4 PDF report generation and native sharing.
  - `lib/providers/waste_quiz_provider.dart`: lifecycle phase `WasteQuizPhase.explaining`, `currentExplanation`, `explanationLoading`, `nextQuestion()`, `loadExplanation()`.
  - `lib/widgets/quiz_explanation_overlay.dart`: `QuizExplanationOverlay`, `QuizEssayExplanationOverlay`, `ExplanationBody`.
  - `lib/widgets/waste_quiz_popup.dart`: integration of explanation overlays and result card PDF export button.
  - `lib/Screens/scan_history_screen.dart`: history view explanation expand toggle, "Tersimpan lokal", and PDF export action.
- Tests: `test/models/quiz_explanation_test.dart`, `test/services/quiz_pdf_service_test.dart`, `test/widgets/quiz_explanation_overlay_test.dart`, `test/quiz_explanation_lifecycle_test.dart`, `test/screens/scan_history_screen_test.dart`, `test/services/scan_record_store_test.dart`.

## Why

Students need immediate pedagogical reasoning and educational context immediately after answering each quiz question (`Question → Answer submitted → Result → Detailed explanation → Next question`). Furthermore, students and educators need to reopen these exact explanations later from Scan History without calling AI models again, and export a clean, multi-page PDF report for study or documentation.

## Rules & Decisions

### 1. Lifecycle and Intercept Phase
- Submitting an answer (multiple-choice or essay) transitions the quiz state machine to `WasteQuizPhase.explaining`.
- In `explaining`, the full-screen dimmed popup overlay (`QuizExplanationOverlay` or `QuizEssayExplanationOverlay`) is displayed in front of the active live camera stream.
- Advancing to the next question requires an explicit student tap on "Soal Berikutnya →". On the final question, the action becomes "Selesai Quiz ✓" which triggers session completion and displays the result card.
- Live camera stream and scan suppression remain completely active during explanation; no secondary identification is triggered.

### 2. Explanation Models & Schema Compatibility
- `QuizExplanation` encapsulates educational summary, correctAnswerReason, selectedAnswerFeedback (corrective explanation when wrong), conceptExplanation, category comparison table rows (`ComparisonRow`), rubric rows (`RubricRow`), learningTakeaway, and source grounding references.
- `RecordQuestion` persists an optional `QuizExplanation` in JSON. Backward compatibility is guaranteed: legacy records with missing explanations deserialize cleanly with `null` explanation.
- `ScanRecord.schemaVersion` defaults to `2` for new records; legacy records without `schemaVersion` default to `1`.

### 3. Essay Review & Grading
- Essay explanations show student response, score out of 10, summary feedback, and scoring breakdown rubric table (`Table 1. Scoring breakdown`).
- When graded, score out of 10 contributes directly to trophies per decision 0028.
- If grading is unavailable, feedback is clearly labeled as awaiting evaluation rather than fabricating authoritative scores.
- Native acceptance found Gemma can return a word list for `keyTerms`; the prompt explicitly requires its integer score. Such lists remain score-only, never converted into invented scores. Session completion counts essay questions as well as multiple-choice questions.
- U4b uses Gemma's JSON rubric: Accuracy /4, Key terms /3, Completeness /2, Clarity /1. The integer total must be 0–10 and equal the four integer criterion scores. Invalid or inconsistent grading stays pending; a valid total without a complete valid rubric is score-only. No synthetic rubric rows or AI/source attribution are displayed.

### 4. Scan History Integration
- In `ScanHistoryScreen`, each saved question card includes an inline "Lihat Penjelasan" expand toggle.
- Reopening saved explanations reads directly from local storage (`scan_records.json`) without calling Gemma or network services.
- Sync status pill displays `Tersimpan lokal` (strictly local, no fake cloud synchronization claim).
- Level badge, total trophies, and progress bars match decision 0028 rules.

### 5. PDF Export Service
- `QuizPdfService` builds a multi-page A4 document directly from the canonical `ScanRecord` data.
- Includes session metadata, score/trophies/grade, question-by-question student answers, correct answers, explanation text, comparison tables, rubric tables, learning takeaways, and headers/footers with page numbers.
- Filename is sanitized to ASCII alphanumeric characters (`elio_quiz_<item>_<id>.pdf`).
- Export PDF action is available both on the quiz completion `_ResultCard` and in `ScanHistoryScreen`.


## Mac acceptance fixes (2026-10-28)

- Variable-length answers and explanations are top-level spanning PDF text;
  nested fixed-height rows must not prevent pagination. No trailing divider
  is added after the final question, avoiding an empty final page.
- Missing or unrecognized essay grading stays `essayScore:null`, contributes
  zero trophies, and displays "Menunggu penilaian" in overlay, result, saved
  history and PDF. No synthetic score or rubric is created. Legacy data keeps
  its recorded scores; no history rewrite or migration is required.
- Integrated the merged G2c base while retaining its serialized store, strict
  HOME completion, real question counts and all regression tests.
- Native Mac acceptance uses an external temporary harness with production
  widgets/services and a dedicated test store, preserving the owner's history.

- Debug sample insertion must load and preserve existing history, append only missing sample IDs, and serialize mutations with ordinary record writes. It must never replace the owner’s records.
