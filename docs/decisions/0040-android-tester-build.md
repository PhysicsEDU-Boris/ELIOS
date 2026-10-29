# 0040: Android tester build (A1)

- Status: Accepted (measured on one phone, 29 Oct; see docs/handoff/lane-a.md)
- Date: 2026-10-29
- Amends: 0018 (the question source switch was debug-only; a tester build now shows it too).
- Code: `lib/providers/app_preferences_provider.dart` (`testerBuild`), `lib/services/gemma_quiz_service.dart`,
  `lib/services/device_health.dart`, `lib/services/tester_log.dart`, `lib/widgets/tester_panel.dart`,
  `lib/services/frame_source/{phone_frame_source,yuv_jpeg}.dart`, `android/.../MainActivity.kt`.
- Tests: `test/tester_build_test.dart`.

## Build flavours

- Normal release: bank only, no switch (0018 unchanged). `flutter build apk --release` never shows the panel.
- Tester build: `--dart-define=TESTER_BUILD=true`. Settings > AI Offline shows "Sumber soal: Bank / Gemma"
  (default Bank, not saved, as in 0018), the Gemma state, "Muat Gemma", and the log buttons.
  `effectiveQuestionSource` treats the tester build like a debug build.

## Model delivery

The 2.59 GB model is not in the APK. On Android it is read from the app's external files dir
(`/sdcard/Android/data/com.boris.elio/files/gemma-4-E2B-it.litertlm`) and registered in place with
`FlutterGemma.installModel(...).fromFile(path)` (flutter_gemma 1.9 `FileSourceHandler`: it registers the
path, no copy). No file: state "Model belum ada" with the path to push to; a file smaller than the full
size: "Model belum lengkap". Bank mode works fully without the model. A photo scan cannot name the
object without Gemma, so the screen asks the user to pick the item and still saves the photo to
Scan History.

## Gemma state and lazy load

States: Belum dimuat, Memuat, Siap, Gagal, plus Model belum ada, Dijeda (panas), Dihentikan sistem.
The tester build does not preload (`warmUp` and the launch `prepare()` are skipped); Gemma loads on the
first request or on "Muat Gemma". GPU is tried first, then CPU (existing attempts); the backend that
ran is logged. The OpenCL `uses-native-library` entries come from flutter_gemma's merged manifest.

## Thermal gate

`PowerManager.currentThermalStatus` is polled every 10 s (tester build) and on each request. At
CRITICAL (4) or worse Gemma pauses: the active request is cancelled, new requests return null, a Gemma
quiz session uses bank questions with the text "Ponsel terlalu panas ... Soal dari bank; essay dinilai
nanti", and an essay answer is saved ungraded (pending) with the same reason. Gemma resumes at SEVERE
or below. (Amended 29 Oct after the first phone run: pausing at SEVERE blocked Gemma on a 12 GB phone that
was still fine. SEVERE is now logged but allowed.) The gate check in `_send`/`ensureReady` is synchronous (cached status) so the single-flight
slot of 0003 is unchanged.

## Low-memory kill

A marker file is written before a load and removed on a clean `dispose()`. At launch (tester build) a
leftover marker plus `ApplicationExitInfo` reason SIGNALED, LOW_MEMORY, EXCESSIVE_RESOURCE_USAGE or
FREEZER (or an unknown reason) shows "Gemma dihentikan sistem, mode bank aktif." and blocks Gemma until
the tester taps "Muat Gemma". CRASH_NATIVE shows a crash text. USER_REQUESTED (swipe away) is treated
as clean. Not verified on a phone: whether a real lmkd kill reports one of these codes on Android 15.

## Log

`elio_tester.log` in the external files dir (`adb pull`) and "Bagikan log" (Android share sheet, last
100 KB), "Salin log", "Lihat log", "Hapus log". It holds: app PSS, RSS and free RAM at load and per request,
thermal status, load ms, first-token ms, identify ms, essay-grade ms (both say when the model load
was inside the timing), FlutterError/uncaught errors, lifecycle changes and system memory-pressure
warnings.

## Phone camera

On Android `PhoneFrameSource` uses the image stream only: it keeps the latest YUV_420_888 frame and
turns it into a rotated JPEG in an isolate on capture. `takePicture` is never used there (CameraX
rebinds use cases between the two). The stream stops while the quiz covers the preview. Other
platforms keep `takePicture`. The rotation formula (sensor orientation vs device orientation) is
unit-tested but not seen on a phone.

## Signing and secrets

The APK is signed with the debug key (existing `build.gradle.kts`), fine for sideloading, not for a
store. Firebase client config is read from `.env.*` assets and `google-services.json`; they are copied in
for the build and removed afterwards, never committed. The APK contains that client config, so do not
share the file publicly.

## Viewfinder crop (29 Oct)

The phone photo is cropped to the on-screen box (centre, +20% margin, mapped through the cover-fit of the preview) before Gemma and Scan History see it. Reason: a battery photographed small in a wide frame was named "kaleng aluminium" or "rol film". `cropToViewfinder` is unit-tested; its effect on naming is not yet measured.
