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

## E1 identify speed, "Bukan ini?" picker, background load (branch `feat/e1-identify-speed`, stacked on A1, draft PR base `feat/a1-android-test-apk`)

Decision 0041. Status: code and tests done; phone-checked on the Edge 60 Fusion on 30-31 Oct (table below).

### What changed
- Identify: photo capped at 512 px long side for Gemma only (History keeps the full crop); shorter prompt; "kaleng aluminium" removed from the examples. The resize is inside `_executeSend` after the slot is claimed (an earlier version awaited it before `_send` and broke the single-flight tests of decision 0003).
- Log: `[gemma] photo A B -> C B in N ms (max side 512)`, `request queryMs=... firstTokenMs=...`. Compare these with the A1 numbers above.
- "Bukan ini?" chip beside "Terdeteksi": 13 bank objects, quiz restarts for the pick, photo stays the History photo, B3 pick shows the hazard card. Available until the first question is answered.
- Background load: `warmUp(scanScreen: true)` from the phone scan screen, tester build, only when the model file exists and Gemma is not paused or killed. No launch preload.

### Verified here
- New `test/e1_identify_test.dart` (10 tests); break-checked: old warm-up, old identify (full photo, can prompt) and a disabled `correctItem` each fail their test.
- `flutter analyze` and secret scan clean; full-suite result in the PR description.

### Phone check (30-31 Oct, Edge 60 Fusion, GPU, tester APK, 512 px)
| Check | Result | Measured |
|---|---|---|
| A. Background load, cold | Pass after one fix | Memuat -> Siap, one `background load` line and one load (9.9 s). First build freed the model when the scan screen closed, so reopening reloaded it (7.6 s); the scan screen now keeps the model loaded in the tester build. Leaving the Control screen still frees it (D reloaded: 12.5 s). |
| B. Shutter during load | Pass | One load (5.9 s), no second load, no error. Load start to identify end 29.8 s (identify 27.4 s incl. load; first token 18.9 s). |
| C. Picker, non-B3 | Pass | `item corrected "Kertas" -> "botol plastik"`; quiz restarted with that object's questions; chip gone after the first answer; History shows the picked name and the original photo. PDF export ran ("berhasil diekspor"); the photo inside the PDF was NOT inspected (share sheet only). |
| D. Picker, B3 | Pass | `item corrected "Kertas" -> "baterai"`; hazard card before any question; History shows "Baterai", B3, original photo. |
| E. Battery naming, 3 scans, no picker | Not conclusive | "benda tak dikenal" (frame blurred, battery moving), "baterai", then no name (`ok=true` but the app showed "belum dikenali"). 1 of 3 named a battery; never "kaleng". |
- Identify with the 512 px photo: first token 14.9-18.9 s, request 19.8-23.9 s over B, D and E (A1 build: 17.7-22.3 s first token, 23-27 s request). Photo 28-39 KB -> 22-31 KB; `queryMs=0`.
- Limits: one phone, scan 1 of E was taken while the battery moved, question source was Bank (essays saved ungraded), the raw Gemma reply is not in the log (scan 3's text is unknown).

## E1 photo-size test (30 Oct, Edge 60 Fusion, GPU, 3 objects x 1 round per size)
| Max side | Photo A->B bytes (avg) | queryMs | First token (avg) | Total request (avg) | Named |
|---|---|---|---|---|---|
| 512 | 78k -> 62k | 0 | 18.4 s (17.8, 19.0, 18.6) | 24.8 s | laptop, kaleng minuman, susu |
| 384 | 73k -> 38k | 0 | 18.1 s (18.2, 17.9, 18.3) | 24.3 s | laptop, cup, milk tea |
| 256 | 69k -> 19k | 0 | 17.1 s (16.7, 17.8, 16.7) | 23.6 s | laptop, cup, botol plastik PET |
- Result: shrinking the photo 3x cuts the first token by about 1.3 s (7%), within the 1.2 s spread between scans at one size. Decision: keep 512 (`IDENTIFY_MAX_SIDE` default). Photo size does not matter for speed; the image encoder cost dominates and `queryMs` is 0.
- Accuracy not judged: the owner did not give ground truth for the objects, only 3 scans per size. At 384 and 256 two names came back in English ("cup", "milk tea").
