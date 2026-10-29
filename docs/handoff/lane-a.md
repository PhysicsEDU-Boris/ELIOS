# Lane A handoff

## A1 Android tester APK (branch `feat/a1-android-test-apk`, from `origin/feature/live-scan` b842ce2)

- Built: arm64 release APK, `--dart-define=TESTER_BUILD=true`, 170.4 MB, sha256 `0978e5c134c8a46a48794c7843393d16eed20c4242f9d2d570e27591f2165c4c`, at `build/app/outputs/flutter-apk/app-release.apk` in the worktree `~/GITHUB/ELIO/elios-a1-android-apk`. Debug-signed. Contains the Firebase client config: do not share publicly.
- Decision 0040 (amends 0018). Model is NOT in the APK: push it to `/sdcard/Android/data/com.boris.elio/files/gemma-4-E2B-it.litertlm` (launch the app once first so the folder exists).
- Done: Bank/Gemma switch (tester only), "Model belum ada" state, lazy load, GPU then CPU with backend logged, thermal gate at SEVERE, kill notice on relaunch, in-app log (share/copy/view/clear), Android camera via YUV image stream + isolate JPEG.
- Verified here: analyze clean; 534 tests pass, only the 2 known splash failures; secret scan clean; new tests break against the old behaviour.
- NOT verified (no phone): load ms, first-token ms, identify ms, essay-grade ms, GPU vs CPU on the Mali, real RAM, whether `fromFile` on the external dir loads natively, real lmkd kill code, thermal on a real device, JPEG rotation and the camera stream on the Edge 60 Fusion.
- Next: owner installs and runs the checklist in the A1 report, then pulls `elio_tester.log`.
