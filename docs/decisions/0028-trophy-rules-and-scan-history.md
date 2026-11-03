# 0028: Trophy rules, student levels, and local scan history (H1)

- Status: Accepted
- Date: 2026-10-26
- Covers: Notion UI plan U5 & U6; Figma file `J2jSbARJSyJCStNFeWkWDj` node `100:170`.
- Code:
  - `lib/models/trophy_rules.dart`: `QuizGrade`, `StudentLevel`, `trophiesFor`, `trophiesForScores`, `gradePercent`, `gradeFor`.
  - `lib/models/scan_record.dart`: `ScanCategory`, `RecordQuestion`, `ScanRecord`.
  - `lib/services/scan_record_store.dart`: `ScanRecordStore` (local persistence in `scan_records.json`).
  - `lib/Screens/scan_history_screen.dart`: `ScanHistoryScreen` responsive UI (side-by-side on wide screens, list-then-detail on mobile).
  - `lib/widgets/control_layout.dart`: `HistoryPill` trophy total hook and navigation.
- Tests: `test/models/trophy_rules_test.dart`, `test/services/scan_record_store_test.dart`, `test/screens/scan_history_screen_test.dart`.

## Why

Students need feedback on their quiz performance and a persistent record of items scanned and sorted. Trophies gamify learning waste categorization, while cumulative levels provide long-term progression. The scan history screen allows students to review past scans and understand right vs wrong answers.

## Rules & Decisions

### 1. Trophy Rules & Grading
- **Quiz session trophies**: 10 trophies awarded per correct multiple-choice question (`trophiesFor(session)`). For essay questions, the score out of 10 points is awarded directly as trophies (`trophiesForScores(scores)`).
- **Quiz grade percentage**: `trophies / (questions * 10) * 100`.
  - 100 %: `Sempurna`
  - 80–99 %: `Hebat`
  - 60–79 %: `Bagus`
  - 40–59 %: `Belajar Lagi`
  - < 40 %: `Coba Lagi`
- **Cumulative Student Levels**:
  - 0–99 trophies: `Lv1 Eco Starter`
  - 100–249 trophies: `Lv2 Waste Spotter`
  - 250–499 trophies: `Lv3 Bin Expert`
  - 500–999 trophies: `Lv4 Eco Sorter`
  - 1000+ trophies: `Lv5 Planet Guardian`
  - Each level computes a normalized fractional progress `[0.0, 1.0]` toward the next level threshold (Lv5 is capped at `1.0`).
- **Figma text note**: The Figma design mockup (node 100:170) displays "340 · Level 4". Under the defined boundary rules, 340 trophies falls within 250..499 and is strictly **Level 3 · Bin Expert** with 36% progress. Per task requirements, the boundary rules are followed strictly over the mockup text.

### 2. Scan Record Schema & Local Storage
- `ScanRecord` holds: `id`, `time`, `itemName`, `category` (B3, Recyclable, Organic, Residu), `cropPhotoPath`, `difficulty` (Easy 1Q, Medium 2Q, Hard 3Q), `questions` (`RecordQuestion`: question, yourAnswer, rightAnswer, isCorrect, trophies), and total `trophies`.
- Storage is purely local JSON in the application documents directory (`scan_records.json`) using synchronous file operations to guarantee predictable execution under `FakeAsync` test environments. Firebase cloud synchronization is deferred to task U7.

### 3. Scan History Screen Layout
- Responsive layout threshold: 750 px.
- **Wide view (>= 750 px)**: Side-by-side view with left panel (category filter pills `All`, `B3`, `Recyclable`, `Organic` and scrollable scan cards) and right panel (full inspection of active item, photo thumbnail, difficulty pills, trophy badge, and complete question breakdown).
- **Narrow view (< 750 px)**: Two-row compact header to prevent flex overflow on 390 dp viewports. List view displayed first; selecting an item opens the detail view with a "Back to list" button.
- **Debug Seeder**: Debug builds include a seed action (`Tambah Contoh Data (Debug)`) that loads the 4 sample items matching Figma node 100:170 (Phone, Plastic Bottle, Battery, Banana Peel). This action is excluded in release builds (`!kReleaseMode`).
