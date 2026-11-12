# Local build notes

## 12 Nov 2026 — Setup + Wi-Fi QR merged into base, phone check (`feat/elios3-setup-wifi`)
- APP_COMMIT `e85c30e` (`feature/live-scan` b0ea1fa + setup 0205 + Wi-Fi QR 0204), arm64 debug APK; `adb install -r` on the Edge 60 Fusion, no data clear; History md5 unchanged; no Flutter errors.
- Checked: Scan hub → Pilih kendaraan → Pakai ELIOS → new ELIOS setup (robot stage, Offline/MaixCAM2 pills, 3-step stepper) → "Tampilkan QR Wi-Fi robot" opens the ELIOS 3 QR sheet. Robot itself not connected. Left on Home.

## 12 Nov 2026 — Scoring finish phone check (0214, `feat/scoring-finish`)
- APP_COMMIT `33d2dd7`, arm64 debug APK (LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION); `adb install -r` on the Edge 60 Fusion, no data clear; all 5 History files md5-identical; no Flutter errors in logcat.
- Learn (phone in dark mode): Organic card 22 % (2 of 9 clovers; was 33 % with the old rule). Daily Guides: "Bacaanmu minggu ini", "80 XP panduan", week days, archive "2 edisi" (no streak). Left on Home.

## 12 Nov 2026 — Trophies → XP phone check (0213, `feat/xp-rename`)
- APP_COMMIT `2b8cdcb`, arm64 debug APK (LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION); `adb install -r` on the Edge 60 Fusion, no data clear; all 5 History files md5-identical.
- Home: "220 XP", "155 XP lagi ke Level 3 · pohonmu tumbuh setiap kamu dapat XP". History: "220 XP · Level 2", "155 XP lagi ke Level 3", rows "+10" beside the trophy icon (art kept).
- Pre-existing on `feature/live-scan` (not from this change): History title "Riwayat" wraps one letter per line while the "Tersimpan di perangkat · menunggu sinkronisasi" chip shows. Left on Home.

## 12 Nov 2026 — XP/clovers rebuilt on feature/live-scan (0210–0212, `feat/lesson-xp`)
- The first builds below (`45139a7`, `e68ff7f`) were based on `feat/elios3-motion-more`, not `feature/live-scan`, so they replaced the phone's newer Learn L3 / Home L3 / Daily Guides motion build. Rebased onto `origin/feature/live-scan` 93b98cd and reinstalled APP_COMMIT `59f5b19` (`adb install -r`, no data clear).
- Checked: Home L3 (Lv2, 220, no re-firing celebration), Learn L3 (archive polaroid stack, new bubbles, 8 of 36 clovers, 22 %). All 5 History files md5-identical. Left on Home.

## 12 Nov 2026 — XP/clovers phone test (0210–0212, `feat/lesson-xp`)
- Source / APP_COMMIT `e68ff7f` (first build `45139a7`); arm64 debug APK with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION; Gradle ~38 s. adb from `~/Library/Android/sdk/platform-tools` (not on PATH).
- Motorola Edge 60 Fusion over USB, `com.boris.elio` debug, same signing; `adb install -r` Success, no uninstall/data clear. App data tar backup in the session scratchpad first; all 5 `scan_records*.json` md5-identical after testing.
- Found on `45139a7`: Level-2 celebration on every cold start (seen level saved from the scans-only level before learning XP loaded). Fixed in `e68ff7f`; two cold starts after: no celebration.
- Checked: Home Level 2, 220 trophies, 155 to Lv3; Learn sticker 8 clovers, "8 dari 36 semanggi · 80 XP dari Panduan Harian", ring 22 %. Left on Home. No Mac app, model, firmware or signing change.
## 10 Nov 2026 — ELIOS setup phone test (0205, `feat/elios3-setup-screen`)
- Android only, no Mac bundle/model/signing change. `flutter build apk --debug --target-platform android-arm64` with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `29cc6e4` → `ba2112c` → final `c36ca60`; `.env.dev`/`.env.prod`/`google-services.json` copied from the main checkout for the build (gitignored, removed after).
- Motorola Edge 60 Fusion, `com.boris.elio` debug, same signing; `adb install -r` ×3, no uninstall/data clear. Shared phone lock `~/.elios-phone-lock` taken and released. Left light / Bahasa Indonesia on Home.
## 10 Nov 2026 — Robot Wi-Fi QR sheet phone check (0204, `feat/elios3-wifi-qr-sheet`)
- APP_COMMIT `1567368`; `flutter build apk --debug --target-platform android-arm64` with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION; Gradle 196 s, APK 165 MB, no `.litertlm` in it. `.env.dev`, `.env.prod`, `google-services.json` copied from the main checkout into the worktree (gitignored).
- Edge 60 Fusion, `adb install -r` Success, no data clear; History md5 unchanged; left Indonesian/light. No Mac bundle, model, firmware or signing change.

## 9 Nov 2026 — Learn L2 v3 phone test (0195, `feat/learn-l2v3`)
- Source / APP_COMMIT `1e4810f` (first test build `b54a1b6+l2v3`); `flutter build apk --debug --target-platform android-arm64` with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION; Gradle 36 s. `.env*` and `google-services.json` already present (gitignored).
- Motorola Edge 60 Fusion over USB, `com.boris.elio` debug, same signing; `adb install -r` Success 14:41:23 Jakarta, no uninstall/data clear. App data backed up first (tar in the session scratchpad); the 3 `scan_records.json` files are md5-identical after testing.
- Tested every Learn hub control and sidebar shortcut, EN/ID live switch and light/dark; left the phone in English, light. Results: `docs/test-results/0195-learn-l2v3/README.md`. No Mac bundle, model, firmware or signing change.

## 8 Nov 2026 — Account history cloud setup (0191, PR #101)
- Source / APP_COMMIT `8cdfac1`; Android arm64 debug APK, LIVE_SCAN=true, Flutter 3.44.2. Final clean packaging 7.8 s; APK 156.6 MB at `build/app/outputs/flutter-apk/app-debug.apk`.
- Existing debug signing retained. No USB device connected: APK built, not installed or robot-tested. No Mac bundle, LaunchServices registration, Keychain, firmware or runtime model changes.
- Kept original `assets/models/gemma-4-E2B-it.litertlm` on disk. Replaced directory-wide asset inclusion with the 2 used GLBs; verified no `.litertlm` entry in the APK. Removed task-produced APK outputs/stale packaging state before final package; no owner source/model files deleted.
- Supabase Free project `tymiikfebewqvuokoyru` (Sydney), Cloudinary `zkebg27g`, Vercel `elios5/ai-backend` production deployment `dpl_8gfZviHZBBweAfKjmpaJBdPSVPDk`. Secrets configured only in Vercel; no billing upgrade.
- Live record/cursor/private-photo/ownership tests passed. All 8 EN/ID guide PDFs HTTP 200. Test fixtures removed with owner approval; local transfer helpers stopped. Accidental task-created Vercel `elios-clean` project removed with owner approval.
- Verification: 16 backend tests; full Flutter run 1333 pass / 20 skipped / 1 unchanged design-token spacing failure; follow-up Learn/cloud tests 43 pass and store tests 13 pass. Analyze: 2 unchanged test-file infos. Secret scan clean; store/guide/write-failure tests break-checked.
- Next phone check: A → scan/quiz/photo/explanation/export/EN-ID → B → A; offline/reconnect and guest isolation. Anonymous sign-out cannot recover a guest UID without permanent identity linking.

## 7 Nov 2026 — Settings on both cameras phone test (`feat/settings-both-cameras`)
- Source `e4d7036`, arm64 debug APK, LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `e4d7036`; Gradle 95 s.
- Motorola Edge 60 Fusion over USB, `com.boris.elio` debug, same signing; `adb install -r` Success, no uninstall/data clear.
- Backup of app data (History, prefs, secure storage) in the session scratchpad first. Tested: settings saved as English values; phone camera at 720p (Android ImageReader 1280x720) with `FPS 22-28 • 1280x720` overlay; Easy + 30s timer ended the quiz as "(time's up)", 0 trophies. Click sound not audible (phone Touch sounds off).
- Afterwards the test scan record and settings were put back from the backup: both History files md5-identical, prefs as before (Medium, 60s, 480p, sound on, MaixCAM2), 568 trophies. No Mac app, model, firmware or signing change.

## 7 Nov 2026 — Control haptics phone test (`feat/control-haptics`)
- Source `1c8caee`, main checkout, arm64 debug APK with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `1c8caee`; Gradle 94 s. `.env*` and `google-services.json` already present (gitignored).
- Motorola Edge 60 Fusion over USB, `com.boris.elio` debug, same signing; `adb install -r` Success 16:11:29 Jakarta, no uninstall/data clear. Cold launch OK, no crash.
- Pre-install backup (History, R3 History, scans, prefs) in the session scratchpad; both History files md5-identical after install. Phone has Touch sounds off (haptics on), so only the vibration is felt. No Mac app, model, firmware or signing change.

## 6 Nov 2026 — H3 redesign phone test (`feat/history-h3-redesign`)
- Phone: Motorola Edge 60 Fusion, `com.boris.elio` debug, same signing; `adb install -r` (Success, last 23:47:34 Jakarta). No uninstall/data clear. Cold launch Status ok.
- Built in worktree `../elios-h3-redesign`: arm64 debug APK (157 MB), LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `5385e16+mission+essayfix` (branch + localized essay fix `d67aba3..dfb7f67` applied uncommitted, then removed). `.env.dev/.env.prod` and `android/app/google-services.json` copied in from the main checkout (gitignored, not committed).
- Private backup before install (History, R3 History, photos, prefs) in the session scratchpad; after testing both History files md5-identical. Phone left English/light on Home. No Mac bundle, model, firmware or signing change.

## 5 Nov 2026 — H3 USB acceptance

- Device: Motorola Edge 60 Fusion, Android 16 / API 36; one Android phone connected over USB.
- Installed package: `com.boris.elio`, debug, version 1.0.0 / code 1; updated using `adb install -r`, retaining app data and the existing signing identity. No uninstall or storage clear.
- First H3 build source: `c0238a9`; `flutter build apk --debug --dart-define=LIVE_SCAN=true --dart-define=TESTER_BUILD=true --dart-define=DARK_MODE_OPTION=true --dart-define=APP_COMMIT=c0238a9`.
- APK output reused: `build/app/outputs/flutter-apk/app-debug.apk` (~2.3 GiB, existing assets retained). No model downloads, asset deletion or new application ID.
- Before install: private backup of both History JSON files and scan photos under `/tmp/elios-h3-phone-20261105/owner-backup/`. Main History: 40 records / 120 answers, schemas 2/3; separate R3 test History: 2 records / 6 answers.
- After migration and live explanations: main History schema 4; all original record IDs, times, categories, crops, questions, saved answers, correct answers, scoring and trophies match the backup. UI total remains 442.
- Live AI: Q1 used Gemini 3.1 Flash-Lite after 3.5 Flash-Lite returned 503 (5.86 s); Q2 retry used 3.5 Flash-Lite. Saved explanations carry source/model/generatedAt. No fake records inserted.
- Native TTS inspected through the debug VM: one service instance, `id-ID`, speaking → idle on pause, exit and background; section switching advances the cancellation epoch. Audio pronunciation was not independently heard.
- Offline test temporarily disabled mobile data, then restored the original network state (Wi-Fi off, mobile data on). Cached explanation opened without loading; uncached question offered Coba lagi in 2.9 s, and retry succeeded online.
- Initial question PDF saved in the app reports directory; USB QA identified that Files could not browse it. Refinement switches Android Save to MediaStore Download/ELIOS; both question and whole-record export opened Android's share chooser. No recipient selected or file sent.
- Phone QA found inherited rectangular chips/action and mono detail title, plus PDF notes splitting away from their heading. Regression tests reproduced these before the fixes.
- No Mac ELIOS app built/launched, no LaunchServices changes, no model-store, Keychain or signing changes. Existing `~/Applications/ELIOS.app` and owner model copies were not touched.

- Final refinement APK built from `500ae5a` with the same flags, output, package and signing identity. `assembleDebug` completed in 87.2 s. No dependency, model, Mac bundle or signing changes.
- H3-fix APK (5 Nov): built from `642e5c4` with the same flags/output/package/signing, `adb install -r` over the existing app; `scan_records.json` unchanged (113,543 bytes). An interim build without TESTER_BUILD/DARK_MODE_OPTION was replaced by the flagged build. No Mac bundle, model or signing change.

## 5 Nov 2026 — PR #93 resume build

- Source `96c832a`, branch `feat/ui-localization`; reused `build/app/outputs/flutter-apk/app-debug.apk` (~2.3 GiB).
- Built successfully: `flutter build apk --debug --target-platform android-arm64 --dart-define=LIVE_SCAN=true --dart-define=TESTER_BUILD=true --dart-define=DARK_MODE_OPTION=true --dart-define=APP_COMMIT=96c832a`; Gradle 89.7 s. Existing Kotlin-plugin migration warning only.
- Target: the only connected phone, Motorola Edge 60 Fusion / Android 16 (USB). Same package `com.boris.elio`, debug signing and version 1.0.0+1; in-place `adb install -r`, no uninstall/data clear.
- Private pre-install backup of both History files, photos and settings: `/tmp/elios-pr93-resume-20261105/owner-backup/history-settings.tar` (40 main records, 2 R3 test records).
- No Mac app build/registration, model downloads/copies, Keychain, signing configuration or private configuration changes. Existing Mac app/model stores and original build assets retained.
- Install returned `Success`; package update time 20:41:58 on the phone. Both History JSON files are byte-for-byte identical to the backup after install (40 main / 2 R3 records). App launched successfully in Indonesian/light mode; Home shows 40 scans and 442 trophies, with zero crash/overflow markers in the fresh process log.
- Push hygiene: replaced two harmless key-assignment placeholders in Python docstrings and replayed the local commits; full-history secret scan now passes. Installed APP_COMMIT `96c832a` corresponds to rebased source `5e7ae70`; verified no difference in lib/assets/android/ios/macos/pubspec/l10n build inputs, so no additional APK rebuild was needed.
- 12 Nov, Home L3 (0208): `flutter build apk --debug --target-platform android-arm64` with LIVE_SCAN/TESTER_BUILD/DARK_MODE_OPTION, APP_COMMIT `77a7f28+home-l3`; installed on the Edge 60 Fusion with `adb install -r` (data and model kept). No Mac build, no new app or model copy.
