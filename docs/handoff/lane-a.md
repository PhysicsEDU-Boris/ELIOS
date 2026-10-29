# Lane A handoff

## A1 Android tester APK (branch `feat/a1-android-test-apk`, from `origin/feature/live-scan` b842ce2)

- Built: arm64 release APK, `--dart-define=TESTER_BUILD=true`, 170.4 MB, sha256 `0978e5c134c8a46a48794c7843393d16eed20c4242f9d2d570e27591f2165c4c`, at `build/app/outputs/flutter-apk/app-release.apk` in the worktree `~/GITHUB/ELIO/elios-a1-android-apk`. Debug-signed. Contains the Firebase client config: do not share publicly.
- Decision 0040 (amends 0018). Model is NOT in the APK: push it to `/sdcard/Android/data/com.boris.elio/files/gemma-4-E2B-it.litertlm` (launch the app once first so the folder exists).
- Done: Bank/Gemma switch (tester only), "Model belum ada" state, lazy load, GPU then CPU with backend logged, thermal gate at CRITICAL (was SEVERE, loosened 29 Oct), kill notice on relaunch, in-app log (share/copy/view/clear), Android camera via YUV image stream + isolate JPEG.
- Verified here: analyze clean; 534 tests pass, only the 2 known splash failures; secret scan clean; new tests break against the old behaviour.
- NOT verified (no phone): load ms, first-token ms, identify ms, essay-grade ms, GPU vs CPU on the Mali, real RAM, whether `fromFile` on the external dir loads natively, real lmkd kill code, thermal on a real device, JPEG rotation and the camera stream on the Edge 60 Fusion.
- Phone run, 29 Oct, Motorola Edge 60 Fusion (11.4 GB RAM, Android 15), tester build, GPU backend (no CPU fallback, no crash, no kill, lowMemory never true):
  - Gemma load 49.6 s cold after launch, 5.5 s when the file was cached.
  - Photo identify: first token 17.7-22.3 s, request 23.4-27.1 s (whole step 29-74 s when it includes the load).
  - Question text: first token 2.0-4.2 s, total 20-41 s. Essay grade: first token 2.7 s, total 23.3 s (one sample).
  - App PSS 2.3-2.4 GB after load, 3.3-3.7 GB while answering; phone free RAM 2.3-2.6 GB.
  - Thermal went NONE to LIGHT to MODERATE to SEVERE within a few questions and Gemma kept working. Pausing at SEVERE was too strict (blocked a healthy 12 GB phone), so the pause is now CRITICAL (resume at SEVERE). CRITICAL was never reached.
  - Fixed after the run: ControlScreen.dispose `ref` error, landscape preview box, essays on in the tester build.
  - Open: Gemma sometimes misnames the object (a battery came back as "kaleng minuman"); PDF export and photo rotation not confirmed from the log. Sample size is small (3 loads, 3 identifies, 1 essay).
- Next: owner installs and runs the checklist in the A1 report, then pulls `elio_tester.log`.
