# Handoff — 2 Nov 2026

- Base: `feature/live-scan` at `6b96f4f` (#72 N3 bottom nav merged).
- Never commit the Xcode scheme, `Maixcam.txt`, `docs/module/`, `docs/quiz-review/proposals/`, `.env*`, Firebase config or the model.

## Merge order (owner is merging now)

1. **#75** `chore/n4-into-live-scan` → `feature/live-scan`. Brings #73 (N4 top bar, `2dd92db`) and #74 (L1 Learn v2, `fad51db`); both had merged into `feat/n3-bottom-nav` after #72, so neither reached `feature/live-scan`. Head `305a05f`: +767 ~19 -2.
2. **#76** `feat/h1v4-home` (H1v4 gamified Home). Stacked on #75: after #75 merges, change its base to `feature/live-scan`. Head `55238cc`: +779 ~20 -2.
- Both are drafts: mark ready before merging. The 2 failures are the known `test/theme/elio_tokens_test.dart` ones (font/radius tables, not touched); analyze has 1 old info in `test/question_bank_integrity_test.dart`.
- After both merge, `feature/live-scan` has N4 top bar, Learn v2 and the new Home. `feat/n3-bottom-nav` can then be retired.

## H1v4 gamified Home (decision 0144)

- Figma J2jSbARJSyJCStNFeWkWDj page 321:2358 (v4 light/dark, guest, loading; v3 search and month). Real data only.
- Maths: `lib/models/home_stats.dart` (local days, streaks, bins with residu in Anorganik, accuracy over last 10, week bars, quests). UI: `lib/Screens/home_screen.dart` + `lib/Screens/home/`. Art: `assets/illustrations/home/` (flutter_svg).
- Header trophy pill + bell in the N4 top bar (`ElioTopBar.trailing`, Home only). Bell opens the old notifications panel, moved to `lib/widgets/home_notifications_sheet.dart`; H2 (#70) not implemented.
- Owner decision 2 Nov: quest rewards (+10/+10/+20) count toward trophies and level. Derived per local day from 2 Nov 2026 (`questBonus`), included in `ScanRecordStore.totalTrophies`, so Home, History, Control and the quiz popup agree.
- Search opens simulations via #74's `openSimulation`; lessons/quizzes via `learningResumeIntentProvider`; scans and "Open in History" open History.
- Tests: `test/models/home_stats_test.dart` (19, break-checked), `test/screens/home_screen_test.dart` (15); renders with `H1_RENDER=1` into `docs/test-results/h1v4/widget/`.

## Phone (Edge 60 Fusion, 2 Nov)

- Tester APK from `55238cc` installed with `adb install -r` (data kept, first install 3 Oct unchanged). Learn v2 confirmed back.
- Home = History: 26 scans, 202 trophies, B3 8 / Anorganik 17 / Organik 1, 0 today (all records 29–30 Oct, so no quest bonus). Year grid → 30 Oct → month view: 12 scans. Shots in `docs/test-results/h1v4/`.
- An extra Back key once left ELIO and taps landed in Instagram and a games app; screenshots deleted, nothing known to be posted. Check the foreground app before every adb tap.
- APK build: `adb` is at `~/Library/Android/sdk/platform-tools/adb`. The 2.59 GB Gemma model sits in `assets/models/` in this checkout and gets bundled (2.76 GB APK): move it to `../.gemma-hold/` for the build and back after (done twice, model restored). Command: `flutter build apk --release --target-platform android-arm64 --dart-define=TESTER_BUILD=true --dart-define=APP_COMMIT=<sha>` (decision 0040).

## Differs from Figma / open

- Inter instead of Google Sans Flex (not bundled); "Top" tag drawn in full; no medals "see all"; N4 avatar icon instead of an initial; medals stack at narrow widths; year-grid cells < 48 dp (Month view is the accessible path).
- History total now exceeds the sum of its rows (quest bonus); History has no per-day filter.
- Robotics Beginner and Sustainability Advocate can never unlock (old rules kept).
- `trophiesFor(List<RecordQuestion>)` returns 0 when `ScanRecord.trophies` is omitted; app callers pass it.
- Not re-checked on the phone after the quest-bonus change: other Learn pages, dark Learn.

## Still open from earlier

- Owner data incident: the 29 Oct owner History record is unrecovered; never reconstruct it.
- Next queue: U4c combined native acceptance (back up owner records first, separate test store, Mac build hygiene in `CLAUDE.md`), then U7 Firebase sync, U8 docs/Figma. See [NEXT_TASK.md](NEXT_TASK.md).
- Open PRs besides #75/#76: #71 N2 launch screen, #70 H2 notifications, #67 H1 old home (superseded by #76), #66/#65/#62/#50 docs, #47 firmware (motion off), #24 (latency gate failed).
- Learn v2 open items: rotate the phone inside the video player; Kuis fisika score never saved (pre-existing).
- Design font decision 0091 (draft): check licences before bundling Google Sans Flex.
