# 0030: Result card, trophies, "Scan lagi", and saving into Scan History (U2)

- Status: Accepted
- Date: 2026-10-26
- Covers: Notion UI plan U2 & H1.
- Code:
  - `lib/widgets/waste_quiz_popup.dart`: `_ResultCard`, trophies badge, level progress bar, R1 pending drop notice, "Scan lagi" and "Tutup" buttons.
  - `lib/services/live_scan_state_machine.dart`: `LiveScanState.waitingForRescan`, `BlockReason('waiting_for_rescan')`, `onQuizFinished()`, `rescan()` rearm, `forgetEverything()`.
  - `lib/services/live_scan_controller.dart`: `rescan()`, `forgetEverything()`, hook `onQuizPhase` to `onQuizFinished`.
  - `lib/providers/waste_quiz_provider.dart`: `recordedQuestions`, `cropBytes`, JPEG crop persistence, saving `ScanRecord` to `ScanRecordStore.instance.addRecord()`, logging `session_result` and `rescan_tapped`.
  - `lib/providers/robot_provider.dart`: `r1DropPendingProvider`.
  - `lib/Screens/control_screen.dart`: wire `r1DropPendingProvider` in `_r1Ticker`, wire `onRescan` in `WasteQuizPopup`.
- Tests: `test/services/live_scan_rescan_test.dart`, `test/widgets/result_card_test.dart`.

## Why

After completing a waste quiz session, students need immediate feedback on their performance (how many questions correct, trophies earned, current grade, and overall level progression). The completed scan must be saved locally into Scan History so students and educators can review past sessions. Furthermore, to avoid jarring repeated quizzes on the same object, the live-scan state machine must pause until the student explicitly taps "Scan lagi".

## Rules & Decisions

### 1. Result Card Presentation
- Shows scanned item name and category badge (e.g. Recyclable, B3, Organic, Residu).
- Displays summary: "x dari N benar".
- Displays trophies earned: `+$T Piala` (10 trophies per correct multiple-choice; essay awards score out of 10 points directly as trophies).
- Displays grade badge based on percentage (`trophies / (totalQuestions * 10)`):
  - 100%: `Sempurna`
  - 80–99%: `Hebat`
  - 60–79%: `Bagus`
  - 40–59%: `Belajar Lagi`
  - < 40%: `Coba Lagi`
- Displays user level and progression:
  - Level badge (e.g. `Lv1 · Eco Starter`, `Lv3 · Bin Expert`).
  - Total cumulative trophies (e.g. `20 Total Piala`).
  - `LinearProgressIndicator` showing progress toward the next level threshold.
- Action buttons:
  - "Scan lagi": re-arms the live scan state machine, dismisses the card, and logs `rescan_tapped`.
  - "Tutup": dismisses the card without forcing a rescan state change.

### 2. Saving ScanRecord into Scan History
- When the quiz session completes (last question answered or skipped), `WasteQuizNotifier._finish()` creates a `ScanRecord`.
- If crop bytes exist from the locked frame or camera photo, they are saved as a JPEG file in `${docsDir.path}/scans/scan_<timestamp>.jpg`.
- The `ScanRecord` is stored locally via `ScanRecordStore.instance.addRecord(record)`.
- The `HistoryPill` on the control screen updates automatically via `ChangeNotifier`, and the scan appears immediately in `ScanHistoryScreen`.

### 3. Live Scan State Machine & Rescan Flow
- When a quiz finishes, `LiveScanStateMachine` enters `LiveScanState.waitingForRescan`.
- In `waitingForRescan`, any incoming camera frames are ignored (no locks or questions triggered, block reason `waiting_for_rescan`).
- Tapping "Scan lagi" ends the waiting cooldown by calling `rescan()`.
- Per decision 0020, the item just quizzed remains remembered in `_quizzed` and cannot be quizzed again until it leaves the camera view for 2 seconds (`quizzedObjectAbsentToRearm`). A different object or a moved object will lock normally.
- The debug "forget everything" button in the Debug Scan sheet clears the quizzed list and re-arms immediately.

### 4. R1 Sorting Gate
- When running with `--dart-define=R1=true`, `ControlScreen` tracks robot drop activity (`R1State.sorting` or `R1State.waitBoth`) through `r1DropPendingProvider`.
- While R1 is actively picking, moving to bin, or dropping, the result card displays: `"Robot sedang membuang ke tempat sampah..."` and disables the "Scan lagi" button (`onPressed: null`).
- Once the R1 drop finishes and returns to safe idle, the notice is cleared and "Scan lagi" becomes enabled. Tested using `SimulatedRobot`.

### 5. Diagnostics & Telemetry
- Emits `session_result` event with fields: `{correct, total, trophies}`.
- Emits `rescan_tapped` event upon tapping "Scan lagi".
- Compatible with both `G1_PICKUP_QUIZ_FLOW` and standard live scan.
