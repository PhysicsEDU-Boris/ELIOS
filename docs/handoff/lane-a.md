# Lane A handoff

## A1 Android tester APK (branch `feat/a1-android-test-apk`, from `origin/feature/live-scan` b842ce2)

Status: working on one phone, owner accepted it as "fine for now" on 29 Oct. Local commits only, not pushed, no PR. Decision 0040 (amends 0018).

### Build
- arm64 release, `--dart-define=TESTER_BUILD=true`, debug-signed. Last APK: 170,506,639 bytes, sha256 `17952863a81e0a51e7a665fc3446d31f66f53f02230636c46125464e44f74437`, in the worktree `~/GITHUB/ELIO/elios-a1-android-apk/build/app/outputs/flutter-apk/app-release.apk` (commit e4183b5).
- The build needs gitignored files copied in and removed afterwards: `.env.dev`, `.env.prod`, `.env.android.*`, `android/app/google-services.json`. The APK embeds the Firebase client config: do not share it publicly.
- Install: `adb install -r <apk>`. Model (not in the APK, 2,588,147,712 bytes): `adb push gemma-4-E2B-it.litertlm /sdcard/Android/data/com.boris.elio/files/` after launching the app once. Log: `adb pull /sdcard/Android/data/com.boris.elio/files/elio_tester.log`.

### What it does
- Tester build only: "Sumber soal: Bank / Gemma" switch and log panel (Settings > AI Offline). Normal release stays bank-only. Essay questions are always on in the tester build.
- Model read from the external files dir with `.fromFile()` (registered in place, works on Android). No file: "Model belum ada", bank mode and manual item pick still work (photo kept for History).
- Lazy load (no preload), GPU first then CPU, backend logged. States: not loaded, loading, ready, failed, plus missing, paused, killed.
- Thermal gate pauses Gemma at CRITICAL (resumes at SEVERE). Paused: bank questions with honest text, essay saved ungraded. Low-memory kill marker shows "Gemma dihentikan sistem, mode bank aktif." on relaunch (not seen in practice).
- Camera: Android uses the YUV image stream only, JPEG in an isolate; photo cropped to the viewfinder box (+20% margin) before Gemma and History.
- Log: load, first-token, identify, essay-grade ms, memory, thermal, identified item/material/category, errors. Share/copy/view/clear in the app.

### Measured on Motorola Edge 60 Fusion (11.4 GB RAM, Android 15), GPU backend
- Load: 4.3-5.6 s with the file cached, 41-50 s on a cold launch. No CPU fallback.
- Identify (photo): first token 17.7-22.3 s, request 23-27 s. Slow; the owner called the wait too long.
- Question text: first token 2.0-4.2 s, total 20-41 s.
- Essay grade: 18.4-23.3 s total (4 samples), all usable.
- App PSS 2.3-2.4 GB after load, 3.3-3.7 GB answering; free RAM 2.3-2.6 GB; `lowMemory` never true. No crash, no kill.
- Thermal went NONE to SEVERE within a few questions and Gemma kept working. Pausing at SEVERE blocked a healthy phone, hence CRITICAL. CRITICAL never reached.

### Verified here
- analyze clean; 535 tests pass, only the 2 known splash failures; secret scan clean; new tests fail on the old behaviour.
- Fixed after phone runs: `ref` used in `ControlScreen.dispose`, preview box in landscape, essays on, photo crop.

### Open
- Naming is unreliable: a battery was called "kaleng minuman/aluminium", "rol film" or "kertas"; Gemma's category for it was often "anorganik" (History still showed B3 because the app maps the name). Cause was a small object in a wide frame; the crop was added, effect unclear (3 scans, objects not recorded). Next lever if needed: remove "kaleng aluminium" from the identify prompt examples.
- Not seen in a log: PDF export success, a real low-memory kill, CPU fallback, a CRITICAL pause.
- Photo-only identify needs the model; without it the user picks from 4 sample items.
- Sample sizes are small (one phone, few runs). The 12 GB figure is this phone only.
- Decision 0040 and CHANGELOG are updated; nothing pushed, no PR, Mac app untouched.
