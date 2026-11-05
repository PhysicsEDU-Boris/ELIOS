# Local build notes

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

## 5 Nov 2026 — Essay keyboard fix phone install (PR #95)

- Only connected phone: Motorola Edge 60 Fusion, Android 16; package `com.boris.elio`, existing debug signing, version 1.0.0+1. `adb install -r` returned Success; lastUpdateTime 21:16:59 (Asia/Jakarta). No uninstall/data clear.
- Preserved the installed PR #93 localization/features: built localized source `d67aba3` plus the PR #95 editor/test change as local integration commit `ffdb236`; localization strings retained. The localized keyboard regression passes. PR source remains `aac5a94` on `feature/live-scan`, with no unrelated localization changes added to #95.
- Reused `build/app/outputs/flutter-apk/app-debug.apk` (~2.3 GiB). `flutter build apk --debug --target-platform android-arm64 --dart-define=LIVE_SCAN=true --dart-define=TESTER_BUILD=true --dart-define=DARK_MODE_OPTION=true --dart-define=APP_COMMIT=ffdb236` succeeded (Gradle 83.7 s; existing Kotlin migration warning).
- Private History/photo/settings backup and reproducible localized source patch: task temp directory `elios-essay-install-5y3bzk0q` under the macOS temporary directory (`phone-data-before.tar`, `localized-build-source.patch`). Existing model assets retained; no downloads/copies.
- App cold launch returned Status ok (3615 ms). After launch, both History files exactly match the backup: main 125309 bytes, R3 test 11455 bytes. No owner records inserted. Physical essay/IME interaction not exercised; owner to type in landscape, hide/reopen keyboard, then submit.
- No Mac app build/registration, firmware, model-store, Keychain, signing or private configuration changes. Only one phone was connected and installed.
