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

## 5 Nov 2026 — PR #93 resume build

- Source `96c832a`, branch `feat/ui-localization`; reused `build/app/outputs/flutter-apk/app-debug.apk` (~2.3 GiB).
- Built successfully: `flutter build apk --debug --target-platform android-arm64 --dart-define=LIVE_SCAN=true --dart-define=TESTER_BUILD=true --dart-define=DARK_MODE_OPTION=true --dart-define=APP_COMMIT=96c832a`; Gradle 89.7 s. Existing Kotlin-plugin migration warning only.
- Target: the only connected phone, Motorola Edge 60 Fusion / Android 16 (USB). Same package `com.boris.elio`, debug signing and version 1.0.0+1; in-place `adb install -r`, no uninstall/data clear.
- Private pre-install backup of both History files, photos and settings: `/tmp/elios-pr93-resume-20261105/owner-backup/history-settings.tar` (40 main records, 2 R3 test records).
- No Mac app build/registration, model downloads/copies, Keychain, signing configuration or private configuration changes. Existing Mac app/model stores and original build assets retained.
- Install returned `Success`; package update time 20:41:58 on the phone. Both History JSON files are byte-for-byte identical to the backup after install (40 main / 2 R3 records). App launched successfully in Indonesian/light mode; Home shows 40 scans and 442 trophies, with zero crash/overflow markers in the fresh process log.
