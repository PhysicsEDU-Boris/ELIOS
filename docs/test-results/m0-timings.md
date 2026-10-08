# M0.1/M0.2: real timing runs — `gemma_offline_test.dart`

- **Date:** 2026-10-08
- **Device:** macOS 27.0 (26A428), arm64 (Flutter macOS desktop target)
- **Flutter:** 3.44.2 (stable)
- **Model file:** `gemma-4-E2B-it.litertlm`, 2,588,147,712 bytes (≈2.59 GB), bundled in place (not copied)
- **Backend:** `PreferredBackend.gpu` (first attempt succeeded every run — no CPU fallback seen)
- **Build mode:** **Debug** (`flutter test integration_test/gemma_offline_test.dart -d macos --dart-define=REQUIRE_OFFLINE=false`; confirmed from the build path `build/macos/Build/Products/Debug/...` in the run logs)
- **Command:** no mock — real model, real chat, run 3 times sequentially, nothing else running on the machine during the runs
- **Environment check before running:** no other `flutter`/`xcodebuild`/`dart` process running; model file present; `flutter doctor` clean except the known, unrelated Android-license warning; `macOS (desktop)` listed as a connected device

All 3 runs: **All tests passed!** (the test's own assertions — phone correctly identified as a phone, 4-option MC question, plain-text chat with no leaked JSON, essay review with no leaked JSON).

## Time to first token (ms)

| Request | Run 1 | Run 2 | Run 3 | Average | Range (min–max) |
|---|---|---|---|---|---|
| identify | 3989 | 3878 | 3827 | **3898** | 3827–3989 (162) |
| question | 464 | 563 | 470 | **499** | 464–563 (99) |
| discuss | 371 | 299 | 288 | **319** | 288–371 (83) |
| essay | 377 | 395 | 300 | **357** | 300–395 (95) |
| review | 375 | 287 | 368 | **343** | 287–375 (88) |

## Total generation time (s), with the stage 0 baseline

| Request | Run 1 | Run 2 | Run 3 | Average | Range (min–max) | Stage 0 baseline | Δ (avg) |
|---|---|---|---|---|---|---|---|
| identify | 4.57 | 4.41 | 4.43 | **4.47** | 4.41–4.57 (0.16) | 5.38 | −0.91 |
| question | 4.41 | 4.46 | 3.61 | **4.16** | 3.61–4.46 (0.85) | 5.14 | −0.98 |
| discuss | 2.69 | 2.88 | 2.10 | **2.56** | 2.10–2.88 (0.78) | 2.41 | +0.15 |
| essay | 3.59 | 2.72 | 3.34 | **3.21** | 2.72–3.59 (0.87) | 3.45 | −0.24 |
| review | 2.35 | 2.83 | 2.50 | **2.56** | 2.35–2.83 (0.48) | 2.98 | −0.42 |

The baseline for discuss (2.41 s) sits inside this run's range (2.10–2.88 s),
so the +0.15 s average difference is not a real regression.

Stage 0 baseline had no first-token figures to compare against — only total
generation time was recorded then, which is why that comparison uses totals.

## Identify: correct item per run

Test photo: `integration_test/fixtures/phone_jpeg.dart` (a phone). Correct
means the test's own check passed: the item names a phone and is not a
bottle.

| Run | Item | Material | Category | Correct |
|---|---|---|---|---|
| 1 | ponsel | logam, plastik, kaca | anorganik | yes |
| 2 | ponsel | logam dan plastik | anorganik | yes |
| 3 | ponsel pintar | logam, plastik, kaca | anorganik | yes |

## Other timings (not part of the per-request table above)

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Vision model load (`ensureReady(vision: true)`) | 5s | 2s | 2s |
| Test-internal total (`sw.elapsed`, load + all 5 requests) | 23s | 20s | 18s |
| Full script wall time (build + launch + test) | 6m27s | 1m38s | 1m37s |

Run 1's script time includes the first Debug Xcode build for this clone
(CocoaPods already installed from the earlier `flutter run`); runs 2 and 3
reused the cached build, which is why they're ~4x faster end to end. The
in-test timings (the two tables above) are unaffected by this — they only
measure the model itself, after the app is already running.

## Raw logs

Full `flutter test` output for each run (including all source text Gemma
generated) is kept outside the repo at `~/GITHUB/ELIO/elios-m0-logs/run-{1,2,3}.log`
— not copied in here since it's generated test output, not something to track.
