# L2 localization results (decision 0185)

- Audit: `python3 tools/l10n/audit_strings.py` -> 0.
- Tests: `test/l10n/l2_bilingual_test.dart` (18), `test/l10n/l2_live_switch_test.dart` (4); each new test break-checked (fails with its fix removed). Full suite and analyze: see the PR.
- Renders: `app/` (36 = en/id x light/dark x 9 H3 states) and `compare/` (Figma | app) from `L10N_RENDER=1 flutter test test/history/h3_figma_harness_test.dart`; no overflow.

## Phone (USB)

Motorola Edge 60 Fusion, Android 16, 1220x2712 @ 450 dpi (434 dp). Debug APK with LIVE_SCAN, TESTER_BUILD, DARK_MODE_OPTION, `adb install -r` (data kept). History backed up privately first (40 records, schema 4; migrates to 5 on next save).

- Sidebar switch id <-> en on Home, Learn, Config, History, Control: `phone/<screen>-<lang>.png`; the open screen changes at once.
- Old Indonesian record "Modul buck converter" opened in English: skeleton (`detail-en-translating`), one Gemini call (8.2 s, gemini-3.1-flash-lite), then English (`detail-en-1`, `-2`, `explanation-en-1`); reopen: 0 AI calls. Two earlier tries were rejected by the validator (answers reworded; records without options) and fixed.
- TTS: en-US voice in English, id-ID in Indonesian (Google TTS log); Pause stops speech.
- Question PDF: `question-en.pdf` (English, cached translation) and `question-id.pdf` (original). Both left in the phone's Download/ELIOS.
- Learn module titles from Firestore stay as stored (no `i18n` yet), by design.
- Not done: airplane-mode check (owner toggles it), dark-mode pairs.

## Interrupted-task resume (5 Nov 2026)

- Reviewed PR #93, both earlier localization sessions and the local handoff. Local branch already contains #94 and the completed L2 commits; remote PR was still at the first localization pass.
- Fixed the remaining clipped Indonesian arm caption using the side gap while preserving natural caption height. Six real-font tests (915x412, 800x360, 932x430, light/dark) fail on the old clipping and pass with the fix; STOP stays on screen.
- `flutter analyze`: no errors/warnings; two existing info notes in m2c_identification_test.dart and question_bank_integrity_test.dart.
- Backend `node --test`: 12 passed. ARB/assets/Firestore translation self-checks pass. String audit: 0. Secret scan: clean.
- Existing theme test failure is unchanged from feature/live-scan: spacing/radii test dereferences a missing radius; its test and theme files have no diff against the base.
- Before install: private backup of both History files, scan photos and preferences at `/tmp/elios-pr93-resume-20261105/owner-backup/history-settings.tar`; 40 main records and 2 R3 test records. Never uninstall or clear storage.
- Backend deployment and Firestore upload remain owner actions. English bank review and the module source PDF re-export remain pending, as described in decision 0185.
- Final full Flutter suite: 1,302 passed, 20 skipped, 1 unchanged theme-test failure. New caption regressions all pass. No additional functional phone acceptance in this resume; owner will check the installed app.
- Final APK `96c832a` built with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, installed successfully with `adb install -r`, and launched in Indonesian/light mode. Both History files unchanged byte-for-byte; Home shows 40 scans / 442 trophies; fresh launch log has no crash or RenderFlex overflow. Only one phone was connected.
